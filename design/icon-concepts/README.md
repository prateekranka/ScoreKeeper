# PipCount Icon Composer concepts

- `hero-cup/`: mascot-forward close-up.
- `arcade-token/`: collectible token with embossed mascot.

Each numbered subfolder is intended to become one Icon Composer group, ordered back-to-front. Source artwork is a flat 1024×1024 SVG with no baked icon mask, blur, shadow, or glass effect.

## Apple Icon Composer deliverables

- `apple-icon-composer/PipCount-Hero-Cup.icon`
- `apple-icon-composer/PipCount-Arcade-Token.icon`

Both packages use the shared square platform configuration for iPhone, iPad, and Mac. Their artwork is a pixel-faithful crop of the approved top-left and bottom-left concepts from `reference/original-four-concepts.png`; the same canonical artwork is retained in default and dark appearances, with the system-generated tinted appearance available separately. Glass, custom shadow, specular, fill replacement, and translucency are disabled on the artwork layer.

`reference/pixel-match-proof.png` shows reference, packaged source, and pixel-difference output from left to right. Both packaged 1024×1024 sources round-trip to their 512×512 reference crops with zero differing pixels.
