/// Errors emitted while creating or simulating Matter values.
@frozen
public enum MatterError: Error, Sendable, Equatable {
    /// A body mass was nonfinite or not greater than zero.
    case invalidMass
    /// A shape dimension was nonfinite or not greater than zero.
    case invalidShapeDimension
    /// Polygon vertices were missing, nonfinite, collinear, or degenerate.
    case invalidPolygon
    /// A polygon was not convex.
    case nonConvexPolygon
    /// A position, velocity, force, or point contained a nonfinite component.
    case invalidVector
    /// An angle, angular velocity, or torque was nonfinite.
    case invalidAngle
    /// Restitution, friction, drag, or slop was outside its supported range.
    case invalidMaterial
    /// A collision category was zero.
    case invalidCollisionFilter
    /// A label was empty or had surrounding whitespace.
    case invalidLabel
    /// Client metadata contained an empty key or untrimmed value.
    case invalidMetadata
    /// A simulation time step was nonfinite or not greater than zero.
    case invalidTimeStep
    /// An engine was asked to perform fewer than one tick.
    case invalidTickCount
    /// A runner or accumulator catch-up limit was not positive.
    case invalidMaximumTicks
    /// Elapsed runner time was negative or nonfinite.
    case invalidElapsedTime
    /// A ray segment had nonfinite or equal endpoints.
    case invalidRay
    /// Solver iterations or numerical tuning values were outside supported ranges.
    case invalidSolverConfiguration
    /// Constraint anchors or numerical tuning values were unsupported.
    case invalidConstraint
    /// Constraint solver iterations were not positive.
    case invalidConstraintSolverConfiguration
    /// A mutation referenced an identifier absent from the world.
    case unknownBody(BodyID)
    /// A mutation referenced a composite absent from the world.
    case unknownComposite(CompositeID)
    /// A mutation referenced a constraint absent from the world.
    case unknownConstraint(ConstraintID)
    /// A batch supplied the same body identifier more than once.
    case duplicateBody(BodyID)
    /// Reparenting would make a composite its own ancestor.
    case compositeCycle
    /// The world's monotonically increasing identifier sequence reached `UInt64.max`.
    case bodyIdentifierExhausted
    /// The world's monotonically increasing composite identifier reached `UInt64.max`.
    case compositeIdentifierExhausted
    /// The world's monotonically increasing constraint identifier reached `UInt64.max`.
    case constraintIdentifierExhausted
}

/// Owns value-type bodies, constraints, composites, and their stable identifiers.
@frozen
public struct World: Sendable, Hashable, Codable {
    /// Value snapshots of the bodies in deterministic insertion order.
    public private(set) var bodies: [Body]
    /// Value snapshots of composites in deterministic insertion order.
    public private(set) var composites: [Composite]
    /// Value snapshots of constraints in deterministic insertion order.
    public private(set) var constraints: [Constraint]
    private var nextBodyIdentifier: UInt64
    private var nextCompositeIdentifier: UInt64
    private var nextConstraintIdentifier: UInt64

    /// Creates an empty world whose first identifier in each namespace is one.
    public init() {
        self.bodies = []
        self.composites = []
        self.constraints = []
        self.nextBodyIdentifier = 0
        self.nextCompositeIdentifier = 0
        self.nextConstraintIdentifier = 0
    }

    /// Adds a body and assigns its stable identifier.
    @discardableResult
    public mutating func add(_ definition: BodyDefinition) throws -> BodyID {
        try definition.validate()
        guard nextBodyIdentifier < .max else {
            throw MatterError.bodyIdentifierExhausted
        }

        nextBodyIdentifier += 1
        let identifier = BodyID(rawValue: nextBodyIdentifier)
        bodies.append(Body(id: identifier, definition: definition))
        return identifier
    }

    /// Adds validated bodies atomically and optionally assigns them to a composite.
    ///
    /// Validation or identifier exhaustion leaves the world unchanged.
    @discardableResult
    public mutating func add(
        _ definitions: [BodyDefinition],
        to composite: CompositeID? = nil
    ) throws -> [BodyID] {
        let destinationIndex: Int?
        if let composite {
            destinationIndex = try compositeIndex(for: composite)
        } else {
            destinationIndex = nil
        }
        try definitions.forEach { try $0.validate() }
        guard UInt64(definitions.count) <= UInt64.max - nextBodyIdentifier else {
            throw MatterError.bodyIdentifierExhausted
        }
        guard !definitions.isEmpty else { return [] }

        let firstIdentifier = nextBodyIdentifier + 1
        let identifiers = definitions.indices.map {
            BodyID(rawValue: firstIdentifier + UInt64($0))
        }
        bodies.append(
            contentsOf: zip(identifiers, definitions).map { identifier, definition in
                Body(id: identifier, definition: definition)
            }
        )
        nextBodyIdentifier += UInt64(definitions.count)
        if let destinationIndex {
            for identifier in identifiers {
                composites[destinationIndex].append(identifier)
            }
        }
        return identifiers
    }

    /// Returns the body with a stable identifier, or `nil` when it is absent.
    public func body(withID identifier: BodyID) -> Body? {
        bodies.first { $0.id == identifier }
    }

    /// Applies a force that the next simulation tick consumes.
    public mutating func applyForce(_ force: Vector, to identifier: BodyID) throws {
        guard force.isFinite else { throw MatterError.invalidVector }
        guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
            throw MatterError.unknownBody(identifier)
        }

        bodies[index].applyForce(force)
    }

    /// Applies a force at a world-space point, accumulating linear force and torque.
    public mutating func applyForce(
        _ force: Vector,
        at point: Vector,
        to identifier: BodyID
    ) throws {
        guard force.isFinite, point.isFinite else { throw MatterError.invalidVector }
        try updateBody(withID: identifier) { body in
            body.applyForce(force, at: point)
        }
    }

    /// Applies torque to a body for the next simulation tick.
    public mutating func applyTorque(_ torque: Float, to identifier: BodyID) throws {
        guard torque.isFinite else { throw MatterError.invalidAngle }
        try updateBody(withID: identifier) { body in
            body.applyTorque(torque)
        }
    }

    /// Mutates a body in place while preserving deterministic world ordering.
    public mutating func updateBody(
        withID identifier: BodyID,
        _ update: (inout Body) throws -> Void
    ) throws {
        guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
            throw MatterError.unknownBody(identifier)
        }
        try update(&bodies[index])
    }

    /// Mutates multiple bodies atomically in one deterministic world operation.
    ///
    /// Identifiers must be unique. If lookup or the update closure throws, no
    /// body is changed.
    public mutating func updateBodies(
        withIDs identifiers: [BodyID],
        _ update: (inout Body) throws -> Void
    ) throws {
        let indices = try bodyIndices(for: identifiers)
        var replacements = indices.map { bodies[$0] }
        for index in replacements.indices {
            try update(&replacements[index])
        }
        for (index, replacement) in zip(indices, replacements) {
            bodies[index] = replacement
        }
    }

    /// Removes and returns a body, or returns `nil` when its identifier is absent.
    @discardableResult
    public mutating func removeBody(withID identifier: BodyID) -> Body? {
        guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
            return nil
        }
        for compositeIndex in composites.indices {
            composites[compositeIndex].remove(identifier)
        }
        removeConstraints(referencing: [identifier])
        return bodies.remove(at: index)
    }

    /// Removes multiple bodies atomically in the supplied order.
    ///
    /// Identifiers must be unique and present. Composite membership is cleaned
    /// automatically.
    @discardableResult
    public mutating func removeBodies(withIDs identifiers: [BodyID]) throws -> [Body] {
        let indices = try bodyIndices(for: identifiers)
        let removed = indices.map { bodies[$0] }
        let removedIDs = Set(identifiers)
        bodies.removeAll { removedIDs.contains($0.id) }
        for index in composites.indices {
            composites[index].remove(removedIDs)
        }
        removeConstraints(referencing: removedIDs)
        return removed
    }

    /// Removes all bodies while keeping identifiers monotonic by default.
    public mutating func removeAllBodies(resetIdentifiers: Bool = false) {
        bodies.removeAll(keepingCapacity: true)
        for index in composites.indices {
            composites[index].removeAllBodies()
        }
        removeAllConstraints()
        if resetIdentifiers {
            nextBodyIdentifier = 0
        }
    }

    /// The number of bodies owned by the world.
    public var bodyCount: Int {
        bodies.count
    }

    /// Adds a validated constraint and captures omitted rest state from the world.
    @discardableResult
    public mutating func addConstraint(
        _ definition: ConstraintDefinition,
        to composite: CompositeID? = nil
    ) throws -> ConstraintID {
        try definition.validate()
        let destinationIndex: Int?
        if let composite {
            destinationIndex = try compositeIndex(for: composite)
        } else {
            destinationIndex = nil
        }
        let firstState = try state(for: definition.first)
        let secondState = try state(for: definition.second)
        guard nextConstraintIdentifier < .max else {
            throw MatterError.constraintIdentifierExhausted
        }

        nextConstraintIdentifier += 1
        let identifier = ConstraintID(rawValue: nextConstraintIdentifier)
        constraints.append(
            Constraint(
                id: identifier,
                definition: definition,
                length: definition.length ?? firstState.point.distance(to: secondState.point),
                referenceAngle: (secondState.angle ?? 0) - (firstState.angle ?? 0)
            )
        )
        if let destinationIndex {
            composites[destinationIndex].append(identifier)
        }
        return identifier
    }

    /// Adds validated constraints atomically and optionally assigns them to a composite.
    ///
    /// Validation, missing bodies, or identifier exhaustion leaves the world unchanged.
    @discardableResult
    public mutating func addConstraints(
        _ definitions: [ConstraintDefinition],
        to composite: CompositeID? = nil
    ) throws -> [ConstraintID] {
        let destinationIndex: Int?
        if let composite {
            destinationIndex = try compositeIndex(for: composite)
        } else {
            destinationIndex = nil
        }
        try definitions.forEach { try $0.validate() }
        let states = try definitions.map { definition in
            let firstState = try state(for: definition.first)
            let secondState = try state(for: definition.second)
            return (
                length: definition.length ?? firstState.point.distance(to: secondState.point),
                referenceAngle: (secondState.angle ?? 0) - (firstState.angle ?? 0)
            )
        }
        guard UInt64(definitions.count) <= UInt64.max - nextConstraintIdentifier else {
            throw MatterError.constraintIdentifierExhausted
        }
        guard !definitions.isEmpty else { return [] }

        let firstIdentifier = nextConstraintIdentifier + 1
        let identifiers = definitions.indices.map {
            ConstraintID(rawValue: firstIdentifier + UInt64($0))
        }
        constraints.append(
            contentsOf: zip(zip(identifiers, definitions), states).map { pair, state in
                Constraint(
                    id: pair.0,
                    definition: pair.1,
                    length: state.length,
                    referenceAngle: state.referenceAngle
                )
            }
        )
        nextConstraintIdentifier += UInt64(definitions.count)
        if let destinationIndex {
            for identifier in identifiers {
                composites[destinationIndex].append(identifier)
            }
        }
        return identifiers
    }

    /// Returns the constraint with a stable identifier, or `nil` when absent.
    public func constraint(withID identifier: ConstraintID) -> Constraint? {
        constraints.first { $0.id == identifier }
    }

    /// Moves the fixed endpoint of an existing point-to-body constraint.
    ///
    /// - Throws: ``MatterError/invalidVector`` for a nonfinite point,
    ///   ``MatterError/unknownConstraint(_:)`` for a missing identifier, or
    ///   ``MatterError/invalidConstraint`` when neither endpoint is fixed.
    public mutating func setFixedPoint(
        _ point: Vector,
        forConstraintWithID identifier: ConstraintID
    ) throws {
        guard point.isFinite else { throw MatterError.invalidVector }
        guard let index = constraints.firstIndex(where: { $0.id == identifier }) else {
            throw MatterError.unknownConstraint(identifier)
        }
        try constraints[index].setFixedPoint(point)
    }

    /// Removes and returns a constraint, cleaning composite membership.
    @discardableResult
    public mutating func removeConstraint(withID identifier: ConstraintID) -> Constraint? {
        guard let index = constraints.firstIndex(where: { $0.id == identifier }) else {
            return nil
        }
        for compositeIndex in composites.indices {
            composites[compositeIndex].remove(identifier)
        }
        return constraints.remove(at: index)
    }

    /// Removes every constraint while keeping identifiers monotonic by default.
    public mutating func removeAllConstraints(resetIdentifiers: Bool = false) {
        constraints.removeAll(keepingCapacity: true)
        for index in composites.indices {
            composites[index].removeAllConstraints()
        }
        if resetIdentifiers {
            nextConstraintIdentifier = 0
        }
    }

    /// The number of constraints owned by the world.
    public var constraintCount: Int {
        constraints.count
    }

    /// Adds a validated composite below an optional existing parent.
    @discardableResult
    public mutating func addComposite(
        label: String = "Composite",
        metadata: [String: String] = [:],
        parent: CompositeID? = nil
    ) throws -> CompositeID {
        try Composite.validate(label: label, metadata: metadata)
        if let parent {
            _ = try compositeIndex(for: parent)
        }
        guard nextCompositeIdentifier < .max else {
            throw MatterError.compositeIdentifierExhausted
        }

        nextCompositeIdentifier += 1
        let identifier = CompositeID(rawValue: nextCompositeIdentifier)
        composites.append(
            Composite(id: identifier, label: label, metadata: metadata, parent: parent)
        )
        return identifier
    }

    /// Returns the composite with a stable identifier, or `nil` when absent.
    public func composite(withID identifier: CompositeID) -> Composite? {
        composites.first { $0.id == identifier }
    }

    /// Returns root composites or direct children in stable insertion order.
    public func childComposites(of parent: CompositeID? = nil) -> [Composite] {
        composites.filter { $0.parent == parent }
    }

    /// Returns the composite that directly contains a body, if one exists.
    public func composite(containing body: BodyID) -> Composite? {
        composites.first { $0.bodyIDs.contains(body) }
    }

    /// Returns the composite that directly contains a constraint, if one exists.
    public func composite(containing constraint: ConstraintID) -> Composite? {
        composites.first { $0.constraintIDs.contains(constraint) }
    }

    /// Assigns an existing body directly to a composite, moving prior membership.
    public mutating func assignBody(_ body: BodyID, to composite: CompositeID) throws {
        guard self.body(withID: body) != nil else {
            throw MatterError.unknownBody(body)
        }
        let destination = try compositeIndex(for: composite)
        for index in composites.indices where index != destination {
            composites[index].remove(body)
        }
        if !composites[destination].bodyIDs.contains(body) {
            composites[destination].append(body)
        }
    }

    /// Removes a body's direct composite membership and returns its former owner.
    @discardableResult
    public mutating func unassignBody(_ body: BodyID) throws -> CompositeID? {
        guard self.body(withID: body) != nil else {
            throw MatterError.unknownBody(body)
        }
        guard let index = composites.firstIndex(where: { $0.bodyIDs.contains(body) }) else {
            return nil
        }
        let identifier = composites[index].id
        composites[index].remove(body)
        return identifier
    }

    /// Assigns an existing constraint to a composite, moving prior membership.
    public mutating func assignConstraint(
        _ constraint: ConstraintID,
        to composite: CompositeID
    ) throws {
        guard self.constraint(withID: constraint) != nil else {
            throw MatterError.unknownConstraint(constraint)
        }
        let destination = try compositeIndex(for: composite)
        for index in composites.indices where index != destination {
            composites[index].remove(constraint)
        }
        if !composites[destination].constraintIDs.contains(constraint) {
            composites[destination].append(constraint)
        }
    }

    /// Removes a constraint's direct composite membership and returns its former owner.
    @discardableResult
    public mutating func unassignConstraint(_ constraint: ConstraintID) throws -> CompositeID? {
        guard self.constraint(withID: constraint) != nil else {
            throw MatterError.unknownConstraint(constraint)
        }
        guard
            let index = composites.firstIndex(where: { $0.constraintIDs.contains(constraint) })
        else {
            return nil
        }
        let identifier = composites[index].id
        composites[index].remove(constraint)
        return identifier
    }

    /// Returns bodies assigned to a composite and, by default, all descendants.
    ///
    /// Results follow stable world body order rather than hierarchy traversal order.
    public func bodies(
        in composite: CompositeID,
        includingDescendants: Bool = true
    ) throws -> [Body] {
        let index = try compositeIndex(for: composite)
        var compositeIDs: Set<CompositeID> = [composites[index].id]
        if includingDescendants {
            compositeIDs.formUnion(descendantCompositeIDs(of: composite))
        }
        let bodyIDs = Set(
            composites.lazy
                .filter { compositeIDs.contains($0.id) }
                .flatMap(\.bodyIDs)
        )
        return bodies.filter { bodyIDs.contains($0.id) }
    }

    /// Returns constraints assigned to a composite and, by default, all descendants.
    public func constraints(
        in composite: CompositeID,
        includingDescendants: Bool = true
    ) throws -> [Constraint] {
        let index = try compositeIndex(for: composite)
        var compositeIDs: Set<CompositeID> = [composites[index].id]
        if includingDescendants {
            compositeIDs.formUnion(descendantCompositeIDs(of: composite))
        }
        let constraintIDs = Set(
            composites.lazy
                .filter { compositeIDs.contains($0.id) }
                .flatMap(\.constraintIDs)
        )
        return constraints.filter { constraintIDs.contains($0.id) }
    }

    /// Moves a composite below a new parent, rejecting hierarchy cycles.
    public mutating func reparentComposite(
        _ composite: CompositeID,
        to parent: CompositeID?
    ) throws {
        let index = try compositeIndex(for: composite)
        if let parent {
            _ = try compositeIndex(for: parent)
            guard parent != composite, !descendantCompositeIDs(of: composite).contains(parent)
            else {
                throw MatterError.compositeCycle
            }
        }
        composites[index].reparent(to: parent)
    }

    /// Removes a composite hierarchy and optionally its assigned world bodies.
    ///
    /// - Returns: Removed composites in stable world insertion order.
    @discardableResult
    public mutating func removeComposite(
        withID identifier: CompositeID,
        removeBodies: Bool = false,
        removeConstraints: Bool = false
    ) throws -> [Composite] {
        _ = try compositeIndex(for: identifier)
        let removedIDs = Set([identifier] + descendantCompositeIDs(of: identifier))
        let removed = composites.filter { removedIDs.contains($0.id) }
        if removeBodies {
            let bodyIDs = Set(removed.flatMap(\.bodyIDs))
            bodies.removeAll { bodyIDs.contains($0.id) }
            self.removeConstraints(referencing: bodyIDs)
        }
        if removeConstraints {
            let constraintIDs = Set(removed.flatMap(\.constraintIDs))
            constraints.removeAll { constraintIDs.contains($0.id) }
        }
        composites.removeAll { removedIDs.contains($0.id) }
        return removed
    }

    /// Removes every composite while optionally removing all assigned bodies.
    public mutating func removeAllComposites(
        removeBodies: Bool = false,
        removeConstraints: Bool = false,
        resetIdentifiers: Bool = false
    ) {
        if removeBodies {
            let bodyIDs = Set(composites.flatMap(\.bodyIDs))
            bodies.removeAll { bodyIDs.contains($0.id) }
            self.removeConstraints(referencing: bodyIDs)
        }
        if removeConstraints {
            let constraintIDs = Set(composites.flatMap(\.constraintIDs))
            constraints.removeAll { constraintIDs.contains($0.id) }
        }
        composites.removeAll(keepingCapacity: true)
        if resetIdentifiers {
            nextCompositeIdentifier = 0
        }
    }

    /// The number of composites owned by the world.
    public var compositeCount: Int {
        composites.count
    }

    mutating func replaceBodies(_ bodies: [Body]) {
        self.bodies = bodies
    }

    mutating func replaceConstraints(_ constraints: [Constraint]) {
        let removed = Set(self.constraints.map(\.id)).subtracting(constraints.map(\.id))
        self.constraints = constraints
        for index in composites.indices {
            composites[index].remove(removed)
        }
    }

    private func state(for anchor: ConstraintAnchor) throws -> (point: Vector, angle: Float?) {
        switch anchor {
        case let .fixed(point):
            return (point, nil)
        case let .body(identifier, local):
            guard let body = body(withID: identifier) else {
                throw MatterError.unknownBody(identifier)
            }
            return (body.position + local.rotated(by: body.angle), body.angle)
        }
    }

    private func bodyIndices(for identifiers: [BodyID]) throws -> [Int] {
        var seen: Set<BodyID> = []
        return try identifiers.map { identifier in
            guard seen.insert(identifier).inserted else {
                throw MatterError.duplicateBody(identifier)
            }
            guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
                throw MatterError.unknownBody(identifier)
            }
            return index
        }
    }

    private func compositeIndex(for identifier: CompositeID) throws -> Int {
        guard let index = composites.firstIndex(where: { $0.id == identifier }) else {
            throw MatterError.unknownComposite(identifier)
        }
        return index
    }

    private func descendantCompositeIDs(of identifier: CompositeID) -> [CompositeID] {
        var descendants: [CompositeID] = []
        var parents: Set<CompositeID> = [identifier]
        var foundChild = true
        while foundChild {
            foundChild = false
            for composite in composites
            where composite.parent.map(parents.contains) == true && !parents.contains(composite.id)
            {
                parents.insert(composite.id)
                descendants.append(composite.id)
                foundChild = true
            }
        }
        return descendants
    }

    private mutating func removeConstraints(referencing bodies: Set<BodyID>) {
        let removed = Set(
            constraints.lazy
                .filter { constraint in bodies.contains { constraint.references($0) } }
                .map(\.id)
        )
        constraints.removeAll { removed.contains($0.id) }
        for index in composites.indices {
            composites[index].remove(removed)
        }
    }
}

/// Deterministic CPU integration for reference implementations and tests.
///
/// ``Engine`` deliberately does not use this type as a fallback: production
/// simulation requires a functioning Metal backend.
public enum ReferenceIntegrator {
    /// Advances every world body using semi-implicit Euler integration.
    public static func step(
        world: inout World,
        gravity: Vector,
        timeStep: Float
    ) throws {
        guard timeStep.isFinite, timeStep > 0 else {
            throw MatterError.invalidTimeStep
        }

        var bodies = world.bodies
        for index in bodies.indices {
            step(body: &bodies[index], gravity: gravity, timeStep: timeStep)
        }
        world.replaceBodies(bodies)
    }

    /// Advances one body using semi-implicit Euler integration.
    public static func step(body: inout Body, gravity: Vector, timeStep: Float) {
        body.integrate(gravity: gravity, timeStep: timeStep)
    }
}

/// Deterministic CPU integration and collision response for tests and tooling.
///
/// Production ``Engine`` uses Metal for integration and the same
/// ``CollisionSolver`` for the explicitly CPU-owned response phase.
public enum ReferencePhysics {
    /// Integrates one tick and resolves its discrete collisions.
    ///
    /// - Returns: Collisions detected after integration and before positional
    ///   correction.
    /// - Throws: ``MatterError/invalidTimeStep`` or
    ///   ``MatterError/invalidSolverConfiguration`` for invalid tuning.
    @discardableResult
    public static func step(
        world: inout World,
        gravity: Vector,
        timeStep: Float,
        solver configuration: SolverConfiguration = .standard,
        constraintSolver constraintConfiguration: ConstraintSolverConfiguration = .standard
    ) throws -> [Collision] {
        try ReferenceIntegrator.step(world: &world, gravity: gravity, timeStep: timeStep)
        try ConstraintSolver.resolve(
            world: &world,
            timeStep: timeStep,
            configuration: constraintConfiguration
        )
        return try CollisionSolver.resolve(world: &world, configuration: configuration)
    }
}
