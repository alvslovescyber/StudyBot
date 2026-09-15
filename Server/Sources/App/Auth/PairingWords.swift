/// The 256 words a pairing code is drawn from (§3.6): common, concrete, unambiguous when read
/// aloud across a room. Six words give 48 bits, which with a ten-minute life and single use
/// is far more than the threat model (one user, one server) needs.
enum PairingWords {
    static let list: [String] = [
        "acorn", "amber", "anchor", "anvil", "apple", "apron", "arrow", "aspen",
        "atlas", "attic", "autumn", "badger", "bagel", "bamboo", "banjo", "barley",
        "barn", "basil", "basket", "beach", "beacon", "beaver", "beetle", "bell",
        "berry", "birch", "biscuit", "bison", "blanket", "bloom", "bobcat", "boulder",
        "bramble", "brass", "breeze", "brick", "bridge", "brook", "bucket", "butter",
        "button", "cabin", "cactus", "camel", "candle", "canoe", "canvas", "canyon",
        "carrot", "castle", "cedar", "cello", "chalk", "cherry", "chestnut", "cider",
        "cinder", "clover", "cobalt", "cocoa", "comet", "compass", "copper", "coral",
        "cotton", "cradle", "crane", "cricket", "crocus", "crystal", "daisy", "dandelion",
        "delta", "desert", "diamond", "dolphin", "dune", "eagle", "ember", "engine",
        "falcon", "feather", "fennel", "fern", "fiddle", "field", "finch", "fjord",
        "flint", "forest", "fossil", "fox", "garden", "garnet", "gazelle", "geyser",
        "ginger", "glacier", "goose", "granite", "grape", "gravel", "grove", "hammer",
        "harbor", "harvest", "hazel", "heron", "hickory", "honey", "horizon", "iceberg",
        "indigo", "iris", "island", "ivory", "jade", "jasmine", "jigsaw", "juniper",
        "kettle", "kingfisher", "kite", "ladder", "lagoon", "lantern", "lark", "lava",
        "lavender", "lemon", "lighthouse", "lilac", "linen", "lion", "lobster", "locust",
        "lotus", "lumber", "magnet", "magpie", "mango", "maple", "marble", "meadow",
        "melon", "mesa", "mint", "mirror", "monsoon", "moss", "mountain", "mulberry",
        "mustard", "nectar", "nettle", "north", "nutmeg", "oak", "oasis", "ocean",
        "olive", "onyx", "orbit", "orchard", "orchid", "osprey", "otter", "oyster",
        "paddle", "pagoda", "palm", "panda", "pansy", "paprika", "parrot", "pebble",
        "pelican", "pepper", "petal", "pewter", "pillow", "pine", "planet", "plum",
        "poppy", "prairie", "prism", "puffin", "pumpkin", "quail", "quartz", "quill",
        "quince", "rabbit", "radish", "raven", "reef", "ribbon", "river", "robin",
        "rocket", "rosemary", "saddle", "saffron", "sage", "salmon", "sandal", "sapphire",
        "satchel", "sequoia", "shadow", "shell", "silver", "sketch", "slate", "sleet",
        "sparrow", "spruce", "squirrel", "starling", "steam", "stone", "storm", "summit",
        "sunflower", "swan", "tadpole", "tangerine", "teapot", "thistle", "thunder", "tiger",
        "timber", "topaz", "torch", "trout", "tulip", "tundra", "turnip", "turtle",
        "umbrella", "valley", "velvet", "violet", "violin", "walnut", "walrus", "wasp",
        "waterfall", "willow", "window", "winter", "wolf", "yarrow", "zebra", "zinc",
    ]
}
