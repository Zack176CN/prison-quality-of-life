"""Assemble the native dispatch console, artwork, menu, and scheduler."""

from . import artwork, feature, language, persistence, registration, ui


def apply(image) -> dict[str, int]:
    symbols = feature.apply(image)
    language_symbols, language_edits = language.prepare(image, symbols["DispatchObjectKind"])
    registration_edits = registration.prepare(
        image,
        dispatch_kind=symbols["DispatchObjectKind"],
        artwork_ready=artwork.apply(image),
        sprite_origin=artwork.SPRITE_ORIGIN,
        register_translations=language_symbols["RegisterDispatchTranslations"],
    )
    for change in (*language_edits, *registration_edits):
        image.patch(*change)
    ui.prepare(image, symbols)
    persistence.apply(image, symbols)
    return symbols
