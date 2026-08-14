#include <metal_stdlib>
using namespace metal;

struct BodyState {
    float positionX;
    float positionY;
    float velocityX;
    float velocityY;
    float forceX;
    float forceY;
    float inverseMass;
    uint isStatic;
};

kernel void integrateBodies(
    device BodyState *bodies [[buffer(0)]],
    constant float2 &gravity [[buffer(1)]],
    constant uint &bodyCount [[buffer(2)]],
    constant float &timeStep [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= bodyCount) {
        return;
    }

    device BodyState &body = bodies[index];
    if (body.isStatic != 0) {
        body.forceX = 0;
        body.forceY = 0;
        return;
    }

    float2 acceleration = gravity + float2(body.forceX, body.forceY) * body.inverseMass;
    float2 velocity = float2(body.velocityX, body.velocityY) + acceleration * timeStep;
    float2 position = float2(body.positionX, body.positionY) + velocity * timeStep;

    body.velocityX = velocity.x;
    body.velocityY = velocity.y;
    body.positionX = position.x;
    body.positionY = position.y;
    body.forceX = 0;
    body.forceY = 0;
}
