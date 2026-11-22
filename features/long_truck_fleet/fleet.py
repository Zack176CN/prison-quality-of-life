"""Link the per-vehicle truck capacity, road geometry, and visual model."""

from features.truck_capacity.feature import definition_edit

from . import capacity, geometry, graphics


def apply(image, dispatch_bindings) -> None:
    bindings, edits = capacity.prepare(image, dispatch_bindings)
    image.patch(*definition_edit(image, 8))
    for change in edits:
        image.patch(*change)
    geometry.apply(image, bindings["GetTruckCapacity"])
    for change in graphics.prepare(image, {**bindings, "FleetWorldEpoch": dispatch_bindings["FleetWorldEpoch"]}):
        image.patch(*change)
