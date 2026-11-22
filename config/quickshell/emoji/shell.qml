pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Portable emoji picker. Bound to SUPER + . in Hyprland. The chosen emoji is
// copied to the clipboard and pasted into the window that was focused before
// the picker opened, so it works in GTK, Qt, Electron and terminal apps.
ShellRoot {
    id: root

    property bool shown: false
    property real reveal: 0
    property bool closing: false

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string recentPath: home + "/.config/quickshell/emoji/recent.json"
    readonly property string clipboardPath: home + "/.config/quickshell/emoji/clipboard.json"
    property var recent: []
    property var clipboard: []
    property var results: []

    property string query: ""
    property string category: "Recent"
    property int selected: 0
    property string targetWindow: ""
    property string pendingText: ""
    property bool pendingOpen: false
    property string internalClipboardValue: ""

    readonly property int columns: root.category === "Clipboard" ? 2 : 7
    readonly property var categories: [
        "Recent", "Clipboard", "Smileys", "Gestures", "Hearts", "Animals",
        "Food", "Activities", "Travel", "Objects", "Symbols", "Flags"
    ]

    // Two single-rectangle highlights: one for the category chips and one for
    // the selected cell, both using the top bar's indicator sync pattern.
    property rect categoryHighlightRect: Qt.rect(0, 0, 0, 0)
    property bool categoryHighlightVisible: false
    property bool categoryHighlightAnimate: false
    property rect gridHighlightRect: Qt.rect(0, 0, 0, 0)
    property bool gridHighlightVisible: false
    property bool gridHighlightAnimate: false
    property point gridHoverPoint: Qt.point(-1, -1)
    property bool gridSelectionSnap: false
    property bool suppressHoverFollow: false
    property bool suppressGridHighlight: false

    function categoryHighlightGeometry() {
        for (let i = 0; i < categoryRepeater.count; i++) {
            const item = categoryRepeater.itemAt(i);
            if (!item || item.modelData !== root.category)
                continue;
            const origin = item.mapToItem(categoryTrack, 0, 0);
            return Qt.rect(origin.x, origin.y, item.width, item.height);
        }
        return null;
    }

    function syncCategoryHighlight(animate) {
        const rect = root.categoryHighlightGeometry();
        if (!rect) {
            root.categoryHighlightVisible = false;
            root.categoryHighlightAnimate = false;
            return;
        }

        if (!root.categoryHighlightVisible) {
            root.categoryHighlightAnimate = false;
            root.categoryHighlightRect = rect;
            root.categoryHighlightVisible = true;
            Qt.callLater(function () {
                if (root.categoryHighlightVisible)
                    root.categoryHighlightAnimate = true;
            });
            return;
        }

        root.categoryHighlightAnimate = animate === true;
        root.categoryHighlightRect = rect;
    }

    function gridHighlightGeometry() {
        if (!grid || grid.count === 0 || root.selected < 0
            || root.selected >= grid.count)
            return null;
        if (grid.cellWidth <= 0 || grid.cellHeight <= 0)
            return null;

        const column = root.selected % root.columns;
        const row = Math.floor(root.selected / root.columns);
        // The highlight is a sibling of the grid in the clipped viewport, so
        // its geometry must be viewport-local rather than content-local.
        return Qt.rect(
            column * grid.cellWidth - grid.contentX,
            row * grid.cellHeight - grid.contentY,
            grid.cellWidth,
            grid.cellHeight
        );
    }

    function syncGridHighlight(animate) {
        const rect = root.gridHighlightGeometry();
        if (!rect) {
            root.gridHighlightVisible = false;
            root.gridHighlightAnimate = false;
            return;
        }

        if (!root.gridHighlightVisible) {
            root.gridHighlightAnimate = false;
            root.gridHighlightRect = rect;
            root.gridHighlightVisible = true;
            Qt.callLater(function () {
                if (root.gridHighlightVisible)
                    root.gridHighlightAnimate = true;
            });
            return;
        }

        root.gridHighlightAnimate = animate === true;
        root.gridHighlightRect = rect;
    }

    function syncSelectionToHoverPoint() {
        if (!grid || root.suppressHoverFollow)
            return;
        if (root.gridHoverPoint.x < 0 || root.gridHoverPoint.y < 0)
            return;
        if (grid.cellWidth <= 0 || grid.cellHeight <= 0 || grid.count === 0)
            return;

        const contentX = root.gridHoverPoint.x + grid.contentX;
        const contentY = root.gridHoverPoint.y + grid.contentY;
        const column = Math.floor(contentX / grid.cellWidth);
        const row = Math.floor(contentY / grid.cellHeight);
        if (column < 0 || column >= root.columns || row < 0)
            return;

        const index = row * root.columns + column;
        if (index < 0 || index >= grid.count || index === root.selected)
            return;

        // Scrolling should keep the highlight pinned under the cursor, so this
        // selection change snaps instead of animating across the grid.
        root.gridSelectionSnap = true;
        root.selected = index;
        Qt.callLater(function () { root.gridSelectionSnap = false; });
    }

    onSelectedChanged: {
        if (!root.suppressGridHighlight)
            root.syncGridHighlight(!root.gridSelectionSnap)
    }
    onResultsChanged: root.syncGridHighlight(false)

    Connections {
        target: grid
        ignoreUnknownSignals: true

        // The highlight is in the grid viewport, so scrolling must resync both
        // the hovered cell and the highlight's viewport-local position.
        function onContentXChanged() {
            root.syncSelectionToHoverPoint();
            if (!root.suppressGridHighlight)
                root.syncGridHighlight(false);
        }
        function onContentYChanged() {
            root.syncSelectionToHoverPoint();
            if (!root.suppressGridHighlight)
                root.syncGridHighlight(false);
        }
        function onCellWidthChanged() { root.syncGridHighlight(false) }
        function onCellHeightChanged() { root.syncGridHighlight(false) }
        function onCountChanged() { root.syncGridHighlight(false) }
    }

    // Compact curated set: one canonical entry per emoji, with search aliases.
    readonly property var emojiData: [
        ["😀", "grinning face", "Smileys", "grin happy smile"],
        ["😃", "smiling face with open mouth", "Smileys", "happy joy smile"],
        ["😄", "smiling face with smiling eyes", "Smileys", "happy laugh smile"],
        ["😁", "beaming face", "Smileys", "grin happy smile"],
        ["😆", "laughing face", "Smileys", "lol laugh happy"],
        ["😅", "grinning face with sweat", "Smileys", "relief nervous hot"],
        ["🤣", "rolling on the floor laughing", "Smileys", "lol rofl laugh"],
        ["😂", "face with tears of joy", "Smileys", "lol laugh cry"],
        ["🙂", "slightly smiling face", "Smileys", "smile okay fine"],
        ["🙃", "upside-down face", "Smileys", "silly joke"],
        ["😉", "winking face", "Smileys", "wink flirt"],
        ["😊", "smiling face with smiling eyes", "Smileys", "blush happy shy"],
        ["😇", "smiling face with halo", "Smileys", "angel innocent"],
        ["🥰", "smiling face with hearts", "Smileys", "love adore"],
        ["😍", "heart eyes", "Smileys", "love crush adore"],
        ["🤩", "star struck", "Smileys", "amazed excited star"],
        ["😘", "face blowing a kiss", "Smileys", "kiss love"],
        ["😚", "kissing face with closed eyes", "Smileys", "kiss love"],
        ["🥲", "smiling face with tear", "Smileys", "proud touched cry"],
        ["😋", "face savoring food", "Smileys", "tasty yum tongue"],
        ["😛", "face with tongue", "Smileys", "tongue silly"],
        ["😜", "winking face with tongue", "Smileys", "silly tongue wink"],
        ["🤪", "zany face", "Smileys", "goofy silly wild"],
        ["😝", "squinting face with tongue", "Smileys", "tongue silly"],
        ["🤗", "smiling face with open hands", "Smileys", "hug welcome"],
        ["🤔", "thinking face", "Smileys", "think hmm consider"],
        ["🤨", "face with raised eyebrow", "Smileys", "skeptical doubt"],
        ["😐", "neutral face", "Smileys", "meh calm"],
        ["😑", "expressionless face", "Smileys", "meh blank"],
        ["😶", "face without mouth", "Smileys", "silent quiet"],
        ["😏", "smirking face", "Smileys", "smirk sly"],
        ["🙄", "face with rolling eyes", "Smileys", "eye roll annoyed"],
        ["😬", "grimacing face", "Smileys", "awkward cringe"],
        ["🤐", "zipper-mouth face", "Smileys", "silent secret"],
        ["😳", "flushed face", "Smileys", "shock embarrassed"],
        ["🥺", "pleading face", "Smileys", "puppy eyes please"],
        ["😢", "crying face", "Smileys", "sad tear cry"],
        ["😭", "loudly crying face", "Smileys", "sob sad cry"],
        ["😤", "face with steam from nose", "Smileys", "triumph smug frustrated"],
        ["😠", "angry face", "Smileys", "mad angry"],
        ["😡", "enraged face", "Smileys", "mad furious angry"],
        ["🤯", "exploding head", "Smileys", "mind blown shocked"],
        ["🥳", "partying face", "Smileys", "party celebrate"],
        ["😎", "smiling face with sunglasses", "Smileys", "cool chill"],
        ["🤓", "nerd face", "Smileys", "geek nerd"],
        ["🧐", "face with monocle", "Smileys", "inspect curious"],
        ["😕", "confused face", "Smileys", "unsure confused"],
        ["😮‍💨", "face exhaling", "Smileys", "sigh relief tired"],
        ["😵‍💫", "face with spiral eyes", "Smileys", "dizzy confused"],
        ["🤠", "cowboy hat face", "Smileys", "cowboy western"],
        ["🤡", "clown face", "Smileys", "clown silly"],
        ["😈", "smiling face with horns", "Smileys", "devil mischief"],
        ["👻", "ghost", "Smileys", "boo spooky"],
        ["🤖", "robot face", "Smileys", "bot machine"],

        ["👋", "waving hand", "Gestures", "hello bye wave"],
        ["🤚", "raised back of hand", "Gestures", "hand stop"],
        ["🖐", "hand with fingers splayed", "Gestures", "hand fingers"],
        ["✋", "raised hand", "Gestures", "hand stop high five"],
        ["🖖", "vulcan salute", "Gestures", "spock star trek"],
        ["👌", "ok hand", "Gestures", "okay perfect"],
        ["🤌", "pinched fingers", "Gestures", "italian gesture"],
        ["🤏", "pinching hand", "Gestures", "small tiny"],
        ["✌️", "victory hand", "Gestures", "peace win"],
        ["🤞", "crossed fingers", "Gestures", "luck hope"],
        ["🤟", "love-you gesture", "Gestures", "ily rock"],
        ["🤘", "sign of the horns", "Gestures", "rock metal"],
        ["🤙", "call me hand", "Gestures", "call phone"],
        ["👈", "pointing left", "Gestures", "left point"],
        ["👉", "pointing right", "Gestures", "right point"],
        ["👆", "pointing up", "Gestures", "up point"],
        ["👇", "pointing down", "Gestures", "down point"],
        ["☝️", "index pointing up", "Gestures", "one point"],
        ["👍", "thumbs up", "Gestures", "yes ok like approve"],
        ["👎", "thumbs down", "Gestures", "no dislike reject"],
        ["✊", "raised fist", "Gestures", "fight power solidarity"],
        ["👊", "oncoming fist", "Gestures", "punch bump"],
        ["👏", "clapping hands", "Gestures", "applause clap"],
        ["🙌", "raising hands", "Gestures", "celebrate praise"],
        ["🤲", "palms up together", "Gestures", "receive offer"],
        ["🤝", "handshake", "Gestures", "deal agree"],
        ["🙏", "folded hands", "Gestures", "thanks please pray"],
        ["💪", "flexed biceps", "Gestures", "strong power"],
        ["🫡", "saluting face", "Gestures", "salute respect"],

        ["❤️", "red heart", "Hearts", "love heart red"],
        ["🧡", "orange heart", "Hearts", "love heart orange"],
        ["💛", "yellow heart", "Hearts", "love heart yellow"],
        ["💚", "green heart", "Hearts", "love heart green"],
        ["💙", "blue heart", "Hearts", "love heart blue"],
        ["💜", "purple heart", "Hearts", "love heart purple"],
        ["🩷", "pink heart", "Hearts", "love heart pink"],
        ["🩵", "light blue heart", "Hearts", "love heart cyan"],
        ["🤎", "brown heart", "Hearts", "love heart brown"],
        ["🖤", "black heart", "Hearts", "love heart dark"],
        ["🤍", "white heart", "Hearts", "love heart white"],
        ["💔", "broken heart", "Hearts", " breakup sad"],
        ["❣️", "heart exclamation", "Hearts", "love emphasis"],
        ["💕", "two hearts", "Hearts", "love cute"],
        ["💞", "revolving hearts", "Hearts", "love together"],
        ["💓", "beating heart", "Hearts", "love pulse"],
        ["💗", "growing heart", "Hearts", "love affection"],
        ["💖", "sparkling heart", "Hearts", "love shine"],
        ["💝", "heart with ribbon", "Hearts", "gift love"],
        ["💘", "heart with arrow", "Hearts", "cupid love"],

        ["🐶", "dog face", "Animals", "dog puppy woof"],
        ["🐱", "cat face", "Animals", "cat kitten meow"],
        ["🐭", "mouse face", "Animals", "mouse squeak"],
        ["🐹", "hamster", "Animals", "hamster cute"],
        ["🐰", "rabbit face", "Animals", "bunny rabbit"],
        ["🦊", "fox face", "Animals", "fox clever"],
        ["🐻", "bear face", "Animals", "bear"],
        ["🐼", "panda face", "Animals", "panda"],
        ["🐨", "koala", "Animals", "koala"],
        ["🐯", "tiger face", "Animals", "tiger"],
        ["🦁", "lion face", "Animals", "lion king"],
        ["🐮", "cow face", "Animals", "cow moo"],
        ["🐷", "pig face", "Animals", "pig oink"],
        ["🐸", "frog face", "Animals", "frog ribbit"],
        ["🐵", "monkey face", "Animals", "monkey"],
        ["🐔", "chicken", "Animals", "chicken hen"],
        ["🐧", "penguin", "Animals", "penguin"],
        ["🦄", "unicorn", "Animals", "unicorn magic"],
        ["🐝", "honeybee", "Animals", "bee honey"],
        ["🦋", "butterfly", "Animals", "butterfly"],
        ["🐺", "wolf face", "Animals", "wolf"],
        ["🐴", "horse face", "Animals", "horse"],
        ["🐙", "octopus", "Animals", "octopus"],
        ["🐠", "tropical fish", "Animals", "fish aquarium"],
        ["🐢", "turtle", "Animals", "turtle slow"],
        ["🐣", "hatching chick", "Animals", "chick hatch"],

        ["🍎", "red apple", "Food", "apple fruit red"],
        ["🍊", "tangerine", "Food", "orange fruit"],
        ["🍋", "lemon", "Food", "lemon sour fruit"],
        ["🍌", "banana", "Food", "banana fruit"],
        ["🍉", "watermelon", "Food", "watermelon fruit"],
        ["🍇", "grapes", "Food", "grapes fruit wine"],
        ["🍓", "strawberry", "Food", "strawberry fruit"],
        ["🫐", "blueberries", "Food", "blueberry fruit"],
        ["🍒", "cherries", "Food", "cherries fruit"],
        ["🍑", "peach", "Food", "peach fruit"],
        ["🥭", "mango", "Food", "mango fruit"],
        ["🍍", "pineapple", "Food", "pineapple fruit"],
        ["🥝", "kiwi fruit", "Food", "kiwi fruit"],
        ["🍅", "tomato", "Food", "tomato vegetable"],
        ["🥑", "avocado", "Food", "avocado"],
        ["🥕", "carrot", "Food", "carrot vegetable"],
        ["🌽", "corn", "Food", "corn vegetable"],
        ["🍞", "bread", "Food", "bread toast"],
        ["🧀", "cheese wedge", "Food", "cheese"],
        ["🍕", "pizza", "Food", "pizza food"],
        ["🍔", "hamburger", "Food", "burger food"],
        ["🍟", "french fries", "Food", "fries chips food"],
        ["🌮", "taco", "Food", "taco food"],
        ["🌯", "burrito", "Food", "burrito food"],
        ["🍣", "sushi", "Food", "sushi food"],
        ["🍜", "steaming bowl", "Food", "ramen noodles soup"],
        ["🥗", "green salad", "Food", "salad healthy"],
        ["🍦", "soft ice cream", "Food", "icecream dessert"],
        ["🍪", "cookie", "Food", "cookie dessert"],
        ["🍫", "chocolate bar", "Food", "chocolate dessert"],
        ["☕", "hot beverage", "Food", "coffee tea hot"],
        ["🍵", "teacup", "Food", "tea"],
        ["🧋", "bubble tea", "Food", "boba tea"],
        ["🍺", "beer mug", "Food", "beer drink"],
        ["🍷", "wine glass", "Food", "wine drink"],
        ["🥂", "clinking glasses", "Food", "cheers toast"],

        ["⚽", "soccer ball", "Activities", "football soccer sport"],
        ["🏀", "basketball", "Activities", "basketball sport"],
        ["🏈", "american football", "Activities", "football sport"],
        ["🎾", "tennis", "Activities", "tennis sport"],
        ["🏐", "volleyball", "Activities", "volleyball sport"],
        ["🏓", "ping pong", "Activities", "table tennis sport"],
        ["🏸", "badminton", "Activities", "badminton sport"],
        ["🎯", "bullseye", "Activities", "target darts goal"],
        ["🎮", "video game", "Activities", "game gaming controller"],
        ["🎲", "game die", "Activities", "dice game random"],
        ["🎨", "artist palette", "Activities", "art paint design"],
        ["🎤", "microphone", "Activities", "sing karaoke mic"],
        ["🎧", "headphone", "Activities", "music headphones audio"],
        ["🎬", "clapper board", "Activities", "movie film video"],
        ["🎉", "party popper", "Activities", "party celebrate"],
        ["🎊", "confetti ball", "Activities", "party celebrate"],
        ["🎁", "wrapped gift", "Activities", "gift present"],
        ["🎈", "balloon", "Activities", "party balloon"],
        ["🧩", "puzzle piece", "Activities", "puzzle problem"],

        ["🚗", "automobile", "Travel", "car drive"],
        ["🚕", "taxi", "Travel", "taxi cab"],
        ["🚌", "bus", "Travel", "bus transit"],
        ["🚑", "ambulance", "Travel", "ambulance emergency"],
        ["🚀", "rocket", "Travel", "rocket launch space"],
        ["✈️", "airplane", "Travel", "plane flight travel"],
        ["🚁", "helicopter", "Travel", "helicopter"],
        ["🛸", "flying saucer", "Travel", "ufo alien"],
        ["🚢", "ship", "Travel", "ship boat"],
        ["⛵", "sailboat", "Travel", "sailboat sailing"],
        ["🏝️", "desert island", "Travel", "island beach vacation"],
        ["🏔️", "snow-capped mountain", "Travel", "mountain snow"],
        ["🌋", "volcano", "Travel", "volcano eruption"],
        ["🌊", "water wave", "Travel", "wave ocean sea"],
        ["🗺️", "world map", "Travel", "map travel"],
        ["🧭", "compass", "Travel", "compass direction"],
        ["🏙️", "cityscape", "Travel", "city buildings"],
        ["🌆", "cityscape at dusk", "Travel", "evening city"],
        ["🌃", "night with stars", "Travel", "night city stars"],

        ["💡", "light bulb", "Objects", "idea light bulb"],
        ["🔦", "flashlight", "Objects", "torch light"],
        ["🔥", "fire", "Objects", "fire hot flame lit"],
        ["💧", "droplet", "Objects", "water drop"],
        ["🌈", "rainbow", "Objects", "rainbow pride"],
        ["⭐", "star", "Objects", "star favorite"],
        ["🌟", "glowing star", "Objects", "star shine"],
        ["✨", "sparkles", "Objects", "sparkle magic clean"],
        ["⚡", "high voltage", "Objects", "lightning fast power"],
        ["☀️", "sun", "Objects", "sun sunny day"],
        ["🌙", "crescent moon", "Objects", "moon night"],
        ["🔔", "bell", "Objects", "bell notification"],
        ["📢", "loudspeaker", "Objects", "announcement speaker"],
        ["📱", "mobile phone", "Objects", "phone mobile"],
        ["💻", "laptop", "Objects", "computer laptop code"],
        ["⌨️", "keyboard", "Objects", "keyboard typing"],
        ["🖥️", "desktop computer", "Objects", "computer monitor"],
        ["💾", "floppy disk", "Objects", "save disk"],
        ["🔋", "battery", "Objects", "battery power"],
        ["🔌", "electric plug", "Objects", "plug power"],
        ["📷", "camera", "Objects", "camera photo"],
        ["⏰", "alarm clock", "Objects", "clock alarm time"],
        ["⏳", "hourglass not done", "Objects", "time wait loading"],
        ["📌", "pushpin", "Objects", "pin important"],
        ["📎", "paperclip", "Objects", "clip attach"],
        ["🔒", "locked", "Objects", "lock secure private"],
        ["🔑", "key", "Objects", "key unlock password"],
        ["🔨", "hammer", "Objects", "hammer tool fix"],
        ["🔧", "wrench", "Objects", "wrench tool fix"],
        ["⚙️", "gear", "Objects", "gear settings config"],
        ["🧰", "toolbox", "Objects", "tools toolbox"],
        ["🧲", "magnet", "Objects", "magnet attract"],
        ["🔬", "microscope", "Objects", "science microscope"],
        ["🔭", "telescope", "Objects", "science telescope space"],
        ["📚", "books", "Objects", "books reading"],
        ["✏️", "pencil", "Objects", "pencil edit write"],
        ["📝", "memo", "Objects", "note write todo"],
        ["📋", "clipboard", "Objects", "clipboard copy list"],
        ["🗑️", "wastebasket", "Objects", "trash delete remove"],
        ["💰", "money bag", "Objects", "money cash"],
        ["💳", "credit card", "Objects", "card payment"],
        ["💎", "gem", "Objects", "gem diamond valuable"],
        ["🛒", "shopping cart", "Objects", "cart shop buy"],
        ["🧵", "thread", "Objects", "thread sewing"],
        ["🧶", "yarn", "Objects", "yarn knitting"],

        ["✅", "check mark", "Symbols", "check done yes ok success"],
        ["❌", "cross mark", "Symbols", "cross no wrong fail"],
        ["⚠️", "warning", "Symbols", "warning caution alert"],
        ["❗", "exclamation mark", "Symbols", "important alert"],
        ["❓", "question mark", "Symbols", "question help"],
        ["💯", "hundred points", "Symbols", "hundred perfect score"],
        ["♻️", "recycling symbol", "Symbols", "recycle eco"],
        ["⭕", "hollow circle", "Symbols", "circle correct"],
        ["💤", "zzz", "Symbols", "sleep tired zzz"],
        ["💫", "dizzy symbol", "Symbols", "dizzy sparkle"],
        ["💥", "collision", "Symbols", "boom crash impact"],
        ["💬", "speech balloon", "Symbols", "chat message comment"],
        ["💭", "thought balloon", "Symbols", "think thought"],
        ["👁️", "eye", "Symbols", "eye see view"],
        ["🧠", "brain", "Symbols", "brain smart think"],
        ["🔮", "crystal ball", "Symbols", "fortune magic"],
        ["♨️", "hot springs", "Symbols", "hot springs steam"],
        ["⚓", "anchor", "Symbols", "anchor ship"],
        ["⛔", "no entry", "Symbols", "no entry blocked"],
        ["🚫", "prohibited", "Symbols", "no forbidden blocked"],
        ["ℹ️", "information", "Symbols", "info information help"],
        ["🎵", "musical note", "Symbols", "music note"],
        ["🎶", "musical notes", "Symbols", "music notes"],
        ["🔊", "loud volume", "Symbols", "volume loud sound"],
        ["🔇", "muted", "Symbols", "mute silent volume"],

        ["🏳️", "white flag", "Flags", "flag white flag generic gen white surrender"],
        ["🏴", "black flag", "Flags", "flag black flag generic gen black"],
        ["🏳️‍🌈", "rainbow flag", "Flags", "flag rainbow flag generic gen rainbow pride lgbt"],
        ["🏳️‍⚧️", "transgender flag", "Flags", "flag transgender flag generic gen trans pride"],
        ["🇦🇫", "Afghanistan", "Flags", "flag afghanistan af afg"],
        ["🇦🇽", "Åland Islands", "Flags", "flag åland islands ax ala åland islands aland"],
        ["🇦🇱", "Albania", "Flags", "flag albania al alb"],
        ["🇩🇿", "Algeria", "Flags", "flag algeria dz dza"],
        ["🇦🇸", "American Samoa", "Flags", "flag american samoa as asm"],
        ["🇦🇩", "Andorra", "Flags", "flag andorra ad and"],
        ["🇦🇴", "Angola", "Flags", "flag angola ao ago"],
        ["🇦🇮", "Anguilla", "Flags", "flag anguilla ai aia"],
        ["🇦🇶", "Antarctica", "Flags", "flag antarctica aq ata"],
        ["🇦🇬", "Antigua and Barbuda", "Flags", "flag antigua and barbuda ag atg"],
        ["🇦🇷", "Argentina", "Flags", "flag argentina ar arg"],
        ["🇦🇲", "Armenia", "Flags", "flag armenia am arm"],
        ["🇦🇼", "Aruba", "Flags", "flag aruba aw abw"],
        ["🇦🇺", "Australia", "Flags", "flag australia au aus"],
        ["🇦🇹", "Austria", "Flags", "flag austria at aut"],
        ["🇦🇿", "Azerbaijan", "Flags", "flag azerbaijan az aze"],
        ["🇧🇸", "Bahamas", "Flags", "flag bahamas bs bhs"],
        ["🇧🇭", "Bahrain", "Flags", "flag bahrain bh bhr"],
        ["🇧🇩", "Bangladesh", "Flags", "flag bangladesh bd bgd"],
        ["🇧🇧", "Barbados", "Flags", "flag barbados bb brb"],
        ["🇧🇾", "Belarus", "Flags", "flag belarus by blr"],
        ["🇧🇪", "Belgium", "Flags", "flag belgium be bel"],
        ["🇧🇿", "Belize", "Flags", "flag belize bz blz"],
        ["🇧🇯", "Benin", "Flags", "flag benin bj ben"],
        ["🇧🇲", "Bermuda", "Flags", "flag bermuda bm bmu"],
        ["🇧🇹", "Bhutan", "Flags", "flag bhutan bt btn"],
        ["🇧🇴", "Bolivia", "Flags", "flag bolivia bo bol plurinational state"],
        ["🇧🇶", "Bonaire", "Flags", "flag bonaire bq bes sint eustatius saba"],
        ["🇧🇦", "Bosnia and Herzegovina", "Flags", "flag bosnia and herzegovina ba bih"],
        ["🇧🇼", "Botswana", "Flags", "flag botswana bw bwa"],
        ["🇧🇻", "Bouvet Island", "Flags", "flag bouvet island bv bvt"],
        ["🇧🇷", "Brazil", "Flags", "flag brazil br bra"],
        ["🇮🇴", "British Indian Ocean Territory", "Flags", "flag british indian ocean territory io iot"],
        ["🇻🇬", "British Virgin Islands", "Flags", "flag british virgin islands vg vgb british virgin islands"],
        ["🇧🇳", "Brunei", "Flags", "flag brunei bn brn darussalam"],
        ["🇧🇬", "Bulgaria", "Flags", "flag bulgaria bg bgr"],
        ["🇧🇫", "Burkina Faso", "Flags", "flag burkina faso bf bfa"],
        ["🇧🇮", "Burundi", "Flags", "flag burundi bi bdi"],
        ["🇨🇻", "Cabo Verde", "Flags", "flag cabo verde cv cpv"],
        ["🇰🇭", "Cambodia", "Flags", "flag cambodia kh khm"],
        ["🇨🇲", "Cameroon", "Flags", "flag cameroon cm cmr"],
        ["🇨🇦", "Canada", "Flags", "flag canada ca can"],
        ["🇰🇾", "Cayman Islands", "Flags", "flag cayman islands ky cym"],
        ["🇨🇫", "Central African Republic", "Flags", "flag central african republic cf caf"],
        ["🇹🇩", "Chad", "Flags", "flag chad td tcd"],
        ["🏁", "checkered flag", "Flags", "flag checkered flag finish fin checkered racing"],
        ["🇨🇱", "Chile", "Flags", "flag chile cl chl"],
        ["🇨🇳", "China", "Flags", "flag china cn chn"],
        ["🇨🇽", "Christmas Island", "Flags", "flag christmas island cx cxr"],
        ["🇨🇨", "Cocos Islands", "Flags", "flag cocos islands cc cck cocos keeling islands"],
        ["🇨🇴", "Colombia", "Flags", "flag colombia co col"],
        ["🇰🇲", "Comoros", "Flags", "flag comoros km com"],
        ["🇨🇰", "Cook Islands", "Flags", "flag cook islands ck cok"],
        ["🇨🇷", "Costa Rica", "Flags", "flag costa rica cr cri"],
        ["🇨🇮", "Côte d'Ivoire", "Flags", "flag côte d'ivoire ci civ ivory coast cote divoire côte d'ivoire"],
        ["🇭🇷", "Croatia", "Flags", "flag croatia hr hrv"],
        ["🇨🇺", "Cuba", "Flags", "flag cuba cu cub"],
        ["🇨🇼", "Curaçao", "Flags", "flag curaçao cw cuw"],
        ["🇨🇾", "Cyprus", "Flags", "flag cyprus cy cyp"],
        ["🇨🇿", "Czechia", "Flags", "flag czechia cz cze czech republic"],
        ["🇩🇰", "Denmark", "Flags", "flag denmark dk dnk"],
        ["🇩🇯", "Djibouti", "Flags", "flag djibouti dj dji"],
        ["🇩🇲", "Dominica", "Flags", "flag dominica dm dma"],
        ["🇩🇴", "Dominican Republic", "Flags", "flag dominican republic do dom"],
        ["🇨🇩", "DR Congo", "Flags", "flag dr congo cd cod dr congo democratic republic of the zaire"],
        ["🇪🇨", "Ecuador", "Flags", "flag ecuador ec ecu"],
        ["🇪🇬", "Egypt", "Flags", "flag egypt eg egy"],
        ["🇸🇻", "El Salvador", "Flags", "flag el salvador sv slv"],
        ["🏴󠁧󠁢󠁥󠁮󠁧󠁿", "England", "Flags", "flag england gb-eng eng english"],
        ["🇬🇶", "Equatorial Guinea", "Flags", "flag equatorial guinea gq gnq"],
        ["🇪🇷", "Eritrea", "Flags", "flag eritrea er eri"],
        ["🇪🇪", "Estonia", "Flags", "flag estonia ee est"],
        ["🇸🇿", "Eswatini", "Flags", "flag eswatini sz swz swaziland"],
        ["🇪🇹", "Ethiopia", "Flags", "flag ethiopia et eth"],
        ["🇪🇺", "European Union", "Flags", "flag european union eu eur european union europe"],
        ["🇫🇰", "Falkland Islands", "Flags", "flag falkland islands fk flk falkland islands malvinas islas"],
        ["🇫🇴", "Faroe Islands", "Flags", "flag faroe islands fo fro"],
        ["🇫🇯", "Fiji", "Flags", "flag fiji fj fji"],
        ["🇫🇮", "Finland", "Flags", "flag finland fi fin"],
        ["🇫🇷", "France", "Flags", "flag france fr fra"],
        ["🇬🇫", "French Guiana", "Flags", "flag french guiana gf guf"],
        ["🇵🇫", "French Polynesia", "Flags", "flag french polynesia pf pyf"],
        ["🇹🇫", "French Southern Territories", "Flags", "flag french southern territories tf atf"],
        ["🇬🇦", "Gabon", "Flags", "flag gabon ga gab"],
        ["🇬🇲", "Gambia", "Flags", "flag gambia gm gmb"],
        ["🇬🇪", "Georgia", "Flags", "flag georgia ge geo"],
        ["🇩🇪", "Germany", "Flags", "flag germany de deu"],
        ["🇬🇭", "Ghana", "Flags", "flag ghana gh gha"],
        ["🇬🇮", "Gibraltar", "Flags", "flag gibraltar gi gib"],
        ["🇬🇷", "Greece", "Flags", "flag greece gr grc"],
        ["🇬🇱", "Greenland", "Flags", "flag greenland gl grl"],
        ["🇬🇩", "Grenada", "Flags", "flag grenada gd grd"],
        ["🇬🇵", "Guadeloupe", "Flags", "flag guadeloupe gp glp"],
        ["🇬🇺", "Guam", "Flags", "flag guam gu gum"],
        ["🇬🇹", "Guatemala", "Flags", "flag guatemala gt gtm"],
        ["🇬🇬", "Guernsey", "Flags", "flag guernsey gg ggy"],
        ["🇬🇳", "Guinea", "Flags", "flag guinea gn gin"],
        ["🇬🇼", "Guinea-Bissau", "Flags", "flag guinea-bissau gw gnb"],
        ["🇬🇾", "Guyana", "Flags", "flag guyana gy guy"],
        ["🇭🇹", "Haiti", "Flags", "flag haiti ht hti"],
        ["🇭🇲", "Heard Island and McDonald Islands", "Flags", "flag heard island and mcdonald islands hm hmd"],
        ["🇭🇳", "Honduras", "Flags", "flag honduras hn hnd"],
        ["🇭🇰", "Hong Kong", "Flags", "flag hong kong hk hkg hong kong"],
        ["🇭🇺", "Hungary", "Flags", "flag hungary hu hun"],
        ["🇮🇸", "Iceland", "Flags", "flag iceland is isl"],
        ["🇮🇳", "India", "Flags", "flag india in ind"],
        ["🇮🇩", "Indonesia", "Flags", "flag indonesia id idn"],
        ["🇮🇷", "Iran", "Flags", "flag iran ir irn persia"],
        ["🇮🇶", "Iraq", "Flags", "flag iraq iq irq"],
        ["🇮🇪", "Ireland", "Flags", "flag ireland ie irl"],
        ["🇮🇲", "Isle of Man", "Flags", "flag isle of man im imn"],
        ["🇮🇱", "Israel", "Flags", "flag israel il isr"],
        ["🇮🇹", "Italy", "Flags", "flag italy it ita"],
        ["🇯🇲", "Jamaica", "Flags", "flag jamaica jm jam"],
        ["🇯🇵", "Japan", "Flags", "flag japan jp jpn"],
        ["🇯🇪", "Jersey", "Flags", "flag jersey je jey"],
        ["🇯🇴", "Jordan", "Flags", "flag jordan jo jor"],
        ["🇰🇿", "Kazakhstan", "Flags", "flag kazakhstan kz kaz"],
        ["🇰🇪", "Kenya", "Flags", "flag kenya ke ken"],
        ["🇰🇮", "Kiribati", "Flags", "flag kiribati ki kir"],
        ["🇽🇰", "Kosovo", "Flags", "flag kosovo xk xkx"],
        ["🇰🇼", "Kuwait", "Flags", "flag kuwait kw kwt"],
        ["🇰🇬", "Kyrgyzstan", "Flags", "flag kyrgyzstan kg kgz"],
        ["🇱🇦", "Laos", "Flags", "flag laos la lao people's democratic republic"],
        ["🇱🇻", "Latvia", "Flags", "flag latvia lv lva"],
        ["🇱🇧", "Lebanon", "Flags", "flag lebanon lb lbn"],
        ["🇱🇸", "Lesotho", "Flags", "flag lesotho ls lso"],
        ["🇱🇷", "Liberia", "Flags", "flag liberia lr lbr"],
        ["🇱🇾", "Libya", "Flags", "flag libya ly lby"],
        ["🇱🇮", "Liechtenstein", "Flags", "flag liechtenstein li lie"],
        ["🇱🇹", "Lithuania", "Flags", "flag lithuania lt ltu"],
        ["🇱🇺", "Luxembourg", "Flags", "flag luxembourg lu lux"],
        ["🇲🇴", "Macau", "Flags", "flag macau mo mac macao"],
        ["🇲🇬", "Madagascar", "Flags", "flag madagascar mg mdg"],
        ["🇲🇼", "Malawi", "Flags", "flag malawi mw mwi"],
        ["🇲🇾", "Malaysia", "Flags", "flag malaysia my mys"],
        ["🇲🇻", "Maldives", "Flags", "flag maldives mv mdv"],
        ["🇲🇱", "Mali", "Flags", "flag mali ml mli"],
        ["🇲🇹", "Malta", "Flags", "flag malta mt mlt"],
        ["🇲🇭", "Marshall Islands", "Flags", "flag marshall islands mh mhl"],
        ["🇲🇶", "Martinique", "Flags", "flag martinique mq mtq"],
        ["🇲🇷", "Mauritania", "Flags", "flag mauritania mr mrt"],
        ["🇲🇺", "Mauritius", "Flags", "flag mauritius mu mus"],
        ["🇾🇹", "Mayotte", "Flags", "flag mayotte yt myt"],
        ["🇲🇽", "Mexico", "Flags", "flag mexico mx mex"],
        ["🇫🇲", "Micronesia", "Flags", "flag micronesia fm fsm federated states"],
        ["🇲🇩", "Moldova", "Flags", "flag moldova md mda republic of"],
        ["🇲🇨", "Monaco", "Flags", "flag monaco mc mco"],
        ["🇲🇳", "Mongolia", "Flags", "flag mongolia mn mng"],
        ["🇲🇪", "Montenegro", "Flags", "flag montenegro me mne"],
        ["🇲🇸", "Montserrat", "Flags", "flag montserrat ms msr"],
        ["🇲🇦", "Morocco", "Flags", "flag morocco ma mar"],
        ["🇲🇿", "Mozambique", "Flags", "flag mozambique mz moz"],
        ["🇲🇲", "Myanmar", "Flags", "flag myanmar mm mmr burma"],
        ["🇳🇦", "Namibia", "Flags", "flag namibia na nam"],
        ["🇳🇷", "Nauru", "Flags", "flag nauru nr nru"],
        ["🇳🇵", "Nepal", "Flags", "flag nepal np npl"],
        ["🇳🇱", "Netherlands", "Flags", "flag netherlands nl nld"],
        ["🇳🇨", "New Caledonia", "Flags", "flag new caledonia nc ncl"],
        ["🇳🇿", "New Zealand", "Flags", "flag new zealand nz nzl"],
        ["🇳🇮", "Nicaragua", "Flags", "flag nicaragua ni nic"],
        ["🇳🇪", "Niger", "Flags", "flag niger ne ner"],
        ["🇳🇬", "Nigeria", "Flags", "flag nigeria ng nga"],
        ["🇳🇺", "Niue", "Flags", "flag niue nu niu"],
        ["🇳🇫", "Norfolk Island", "Flags", "flag norfolk island nf nfk"],
        ["🇰🇵", "North Korea", "Flags", "flag north korea kp prk north korea dprk democratic people's republic of"],
        ["🇲🇰", "North Macedonia", "Flags", "flag north macedonia mk mkd north macedonia"],
        ["🏴󠁧󠁢󠁮󠁩󠁲󠁿", "Northern Ireland", "Flags", "flag northern ireland gb-nir nir northern ireland"],
        ["🇲🇵", "Northern Mariana Islands", "Flags", "flag northern mariana islands mp mnp"],
        ["🇳🇴", "Norway", "Flags", "flag norway no nor"],
        ["🇴🇲", "Oman", "Flags", "flag oman om omn"],
        ["🇵🇰", "Pakistan", "Flags", "flag pakistan pk pak"],
        ["🇵🇼", "Palau", "Flags", "flag palau pw plw"],
        ["🇵🇸", "Palestine", "Flags", "flag palestine ps pse palestinian"],
        ["🇵🇦", "Panama", "Flags", "flag panama pa pan"],
        ["🇵🇬", "Papua New Guinea", "Flags", "flag papua new guinea pg png"],
        ["🇵🇾", "Paraguay", "Flags", "flag paraguay py pry"],
        ["🇵🇪", "Peru", "Flags", "flag peru pe per"],
        ["🇵🇭", "Philippines", "Flags", "flag philippines ph phl"],
        ["🏴‍☠️", "pirate flag", "Flags", "flag pirate flag pirate pir jolly roger"],
        ["🇵🇳", "Pitcairn", "Flags", "flag pitcairn pn pcn"],
        ["🇵🇱", "Poland", "Flags", "flag poland pl pol"],
        ["🇵🇹", "Portugal", "Flags", "flag portugal pt prt"],
        ["🇵🇷", "Puerto Rico", "Flags", "flag puerto rico pr pri"],
        ["🇶🇦", "Qatar", "Flags", "flag qatar qa qat"],
        ["🇨🇬", "Republic of the Congo", "Flags", "flag republic of the congo cg cog republic of the congo brazzaville"],
        ["🇷🇪", "Réunion", "Flags", "flag réunion re reu reunion"],
        ["🇷🇴", "Romania", "Flags", "flag romania ro rou"],
        ["🇷🇺", "Russia", "Flags", "flag russia ru rus russian federation"],
        ["🇷🇼", "Rwanda", "Flags", "flag rwanda rw rwa"],
        ["🇧🇱", "Saint Barthélemy", "Flags", "flag saint barthélemy bl blm saint barthélemy barth"],
        ["🇸🇭", "Saint Helena", "Flags", "flag saint helena sh shn saint helena ascension tristan da cunha"],
        ["🇰🇳", "Saint Kitts and Nevis", "Flags", "flag saint kitts and nevis kn kna"],
        ["🇱🇨", "Saint Lucia", "Flags", "flag saint lucia lc lca"],
        ["🇲🇫", "Saint Martin", "Flags", "flag saint martin mf maf saint martin french"],
        ["🇵🇲", "Saint Pierre and Miquelon", "Flags", "flag saint pierre and miquelon pm spm"],
        ["🇻🇨", "Saint Vincent and the Grenadines", "Flags", "flag saint vincent and the grenadines vc vct"],
        ["🇼🇸", "Samoa", "Flags", "flag samoa ws wsm"],
        ["🇸🇲", "San Marino", "Flags", "flag san marino sm smr"],
        ["🇸🇹", "São Tomé and Príncipe", "Flags", "flag são tomé and príncipe st stp sao tome and principe são tomé príncipe"],
        ["🇸🇦", "Saudi Arabia", "Flags", "flag saudi arabia sa sau"],
        ["🏴󠁧󠁢󠁳󠁣󠁴󠁿", "Scotland", "Flags", "flag scotland gb-sct sct scottish"],
        ["🇸🇳", "Senegal", "Flags", "flag senegal sn sen"],
        ["🇷🇸", "Serbia", "Flags", "flag serbia rs srb"],
        ["🇸🇨", "Seychelles", "Flags", "flag seychelles sc syc"],
        ["🇸🇱", "Sierra Leone", "Flags", "flag sierra leone sl sle"],
        ["🇸🇬", "Singapore", "Flags", "flag singapore sg sgp"],
        ["🇸🇽", "Sint Maarten", "Flags", "flag sint maarten sx sxm sint maarten dutch"],
        ["🇸🇰", "Slovakia", "Flags", "flag slovakia sk svk"],
        ["🇸🇮", "Slovenia", "Flags", "flag slovenia si svn"],
        ["🇸🇧", "Solomon Islands", "Flags", "flag solomon islands sb slb"],
        ["🇸🇴", "Somalia", "Flags", "flag somalia so som"],
        ["🇿🇦", "South Africa", "Flags", "flag south africa za zaf"],
        ["🇬🇸", "South Georgia and the South Sandwich Islands", "Flags", "flag south georgia and the south sandwich islands gs sgs"],
        ["🇰🇷", "South Korea", "Flags", "flag south korea kr kor south korea republic of"],
        ["🇸🇸", "South Sudan", "Flags", "flag south sudan ss ssd"],
        ["🇪🇸", "Spain", "Flags", "flag spain es esp"],
        ["🇱🇰", "Sri Lanka", "Flags", "flag sri lanka lk lka"],
        ["🇸🇩", "Sudan", "Flags", "flag sudan sd sdn"],
        ["🇸🇷", "Suriname", "Flags", "flag suriname sr sur"],
        ["🇸🇯", "Svalbard and Jan Mayen", "Flags", "flag svalbard and jan mayen sj sjm"],
        ["🇸🇪", "Sweden", "Flags", "flag sweden se swe"],
        ["🇨🇭", "Switzerland", "Flags", "flag switzerland ch che"],
        ["🇸🇾", "Syria", "Flags", "flag syria sy syr syrian arab republic"],
        ["🇹🇼", "Taiwan", "Flags", "flag taiwan tw twn formosa chinese taipei"],
        ["🇹🇯", "Tajikistan", "Flags", "flag tajikistan tj tjk"],
        ["🇹🇿", "Tanzania", "Flags", "flag tanzania tz tza united republic"],
        ["🇹🇭", "Thailand", "Flags", "flag thailand th tha"],
        ["🇹🇱", "Timor-Leste", "Flags", "flag timor-leste tl tls timor leste east"],
        ["🇹🇬", "Togo", "Flags", "flag togo tg tgo"],
        ["🇹🇰", "Tokelau", "Flags", "flag tokelau tk tkl"],
        ["🇹🇴", "Tonga", "Flags", "flag tonga to ton"],
        ["🇹🇹", "Trinidad and Tobago", "Flags", "flag trinidad and tobago tt tto"],
        ["🇹🇳", "Tunisia", "Flags", "flag tunisia tn tun"],
        ["🇹🇷", "Türkiye", "Flags", "flag türkiye tr tur turkiye turkey"],
        ["🇹🇲", "Turkmenistan", "Flags", "flag turkmenistan tm tkm"],
        ["🇹🇨", "Turks and Caicos Islands", "Flags", "flag turks and caicos islands tc tca"],
        ["🇹🇻", "Tuvalu", "Flags", "flag tuvalu tv tuv"],
        ["🇻🇮", "U.S. Virgin Islands", "Flags", "flag u.s. virgin islands vi vir us virgin islands u.s."],
        ["🇺🇬", "Uganda", "Flags", "flag uganda ug uga"],
        ["🇺🇦", "Ukraine", "Flags", "flag ukraine ua ukr"],
        ["🇦🇪", "United Arab Emirates", "Flags", "flag united arab emirates ae are united arab emirates uae"],
        ["🇬🇧", "United Kingdom", "Flags", "flag united kingdom gb gbr united kingdom uk britain great"],
        ["🇺🇳", "United Nations", "Flags", "flag united nations un unn united nations"],
        ["🇺🇸", "United States", "Flags", "flag united states us usa united states america"],
        ["🇺🇲", "United States Minor Outlying Islands", "Flags", "flag united states minor outlying islands um umi united states minor outlying islands us"],
        ["🇺🇾", "Uruguay", "Flags", "flag uruguay uy ury"],
        ["🇺🇿", "Uzbekistan", "Flags", "flag uzbekistan uz uzb"],
        ["🇻🇺", "Vanuatu", "Flags", "flag vanuatu vu vut"],
        ["🇻🇦", "Vatican City", "Flags", "flag vatican city va vat vatican city holy see"],
        ["🇻🇪", "Venezuela", "Flags", "flag venezuela ve ven bolivarian republic"],
        ["🇻🇳", "Vietnam", "Flags", "flag vietnam vn vnm viet nam"],
        ["🏴󠁧󠁢󠁷󠁬󠁳󠁿", "Wales", "Flags", "flag wales gb-wls wls welsh"],
        ["🇼🇫", "Wallis and Futuna", "Flags", "flag wallis and futuna wf wlf"],
        ["🇪🇭", "Western Sahara", "Flags", "flag western sahara eh esh"],
        ["🇾🇪", "Yemen", "Flags", "flag yemen ye yem"],
        ["🇿🇲", "Zambia", "Flags", "flag zambia zm zmb"],
        ["🇿🇼", "Zimbabwe", "Flags", "flag zimbabwe zw zwe"]
    ]

    readonly property var emojis: {
        const list = [];
        for (let i = 0; i < root.emojiData.length; i++) {
            const item = root.emojiData[i];
            list.push({
                char: item[0], name: item[1], group: item[2], keywords: item[3]
            });
        }
        return list;
    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    function dataFor(char) {
        for (let i = 0; i < root.emojis.length; i++) {
            if (root.emojis[i].char === char)
                return root.emojis[i];
        }
        return { char: char, name: char, group: "Recent", keywords: "" };
    }

    function refreshResults() {
        const q = root.query.trim().toLowerCase();
        let list;

        if (q !== "") {
            const searchable = root.emojis.concat(root.clipboardItems());
            list = searchable.filter(function (item) {
                return item.name.toLowerCase().indexOf(q) >= 0
                    || item.keywords.indexOf(q) >= 0
                    || item.group.toLowerCase().indexOf(q) >= 0
                    || item.char.indexOf(q) >= 0;
            });
        } else if (root.category === "Recent") {
            list = root.recent.map(root.dataFor);
        } else if (root.category === "Clipboard") {
            list = root.clipboardItems();
        } else if (root.category === "All") {
            list = root.emojis;
        } else {
            list = root.emojis.filter(function (item) {
                return item.group === root.category;
            });
        }

        root.results = list;
        root.selected = Math.max(0, Math.min(root.selected, list.length - 1));
    }

    function loadRecent() {
        try {
            const parsed = JSON.parse(recentFile.text() || "[]");
            const list = Array.isArray(parsed) ? parsed : [];
            root.recent = list
                .filter(function (item) { return typeof item === "string"; })
                .slice(0, 24);
        } catch (e) {
            root.recent = [];
        }
        refreshResults();
    }

    function saveRecent() {
        recentWriter.setText(JSON.stringify(root.recent, null, 2) + "\n");
    }

    function addRecent(char) {
        const list = root.recent.filter(function (item) { return item !== char; });
        list.unshift(char);
        root.recent = list.slice(0, 24);
        saveRecent();
    }

    function clipboardPreview(text) {
        const lines = String(text || "").replace(/\r/g, "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "")
                continue;
            return line.length > 44 ? line.slice(0, 43) + "…" : line;
        }
        return "(whitespace)";
    }

    function clipboardItems() {
        return root.clipboard.map(function (text, index) {
            return {
                char: "📋",
                name: "clipboard " + (index + 1),
                group: "Clipboard",
                keywords: "clipboard paste history " + text.toLowerCase().slice(0, 600),
                preview: root.clipboardPreview(text),
                text: text
            };
        });
    }

    function loadClipboard() {
        try {
            const parsed = JSON.parse(clipboardFile.text() || "[]");
            const list = Array.isArray(parsed) ? parsed : [];
            root.clipboard = list
                .filter(function (item) {
                    return typeof item === "string"
                        && item.trim() !== ""
                        && item.length <= 4000;
                })
                .slice(0, 30);
        } catch (e) {
            root.clipboard = [];
        }
    }

    function saveClipboard() {
        clipboardWriter.setText(JSON.stringify(root.clipboard, null, 2) + "\n");
    }

    function clearClipboard() {
        root.clipboard = [];
        saveClipboard();
        root.selected = 0;
        root.refreshResults();
    }

    function probeClipboard() {
        if (!clipboardProbe.running)
            clipboardProbe.running = true;
    }

    function captureClipboard(text) {
        let value = String(text || "")
            .replace(/\u0000/g, "")
            .replace(/\r\n/g, "\n");
        if (value === "" || value.trim() === "" || value.length > 4000)
            return;
        if (value === root.internalClipboardValue)
            return;
        if (root.internalClipboardValue !== "")
            root.internalClipboardValue = "";
        if (root.clipboard.length > 0 && root.clipboard[0] === value)
            return;
        const list = root.clipboard.filter(function (item) { return item !== value; });
        list.unshift(value);
        root.clipboard = list.slice(0, 30);
        saveClipboard();
    }

    function setCategory(name) {
        root.category = name;
        if (field.text !== "")
            field.text = "";
        root.query = "";
        root.selected = 0;
        refreshResults();
    }

    function move(delta) {
        if (root.results.length === 0)
            return;
        // Keyboard navigation owns the selection while the view scrolls, so
        // cursor-follow and scroll snapping stay out of the way until it lands.
        root.suppressHoverFollow = true;
        root.suppressGridHighlight = true;
        root.selected = Math.max(0,
            Math.min(root.results.length - 1, root.selected + delta));
        grid.positionViewAtIndex(root.selected, GridView.Contain);
        Qt.callLater(function () {
            root.suppressHoverFollow = false;
            root.suppressGridHighlight = false;
            root.syncGridHighlight(true);
        });
    }

    function insert(item) {
        if (!item)
            return;
        const value = String(item.text || item.char || "");
        if (value === "")
            return;
        root.pendingText = value;
        if (item.group !== "Clipboard")
            root.addRecent(value);
        root.internalClipboardValue = value;
        copyProcess.command = ["wl-copy", "--", value];
        copyProcess.running = false;
        copyProcess.running = true;
        root.close();
        pasteTimer.restart();
    }

    function parseWindowData(text) {
        try {
            const data = JSON.parse(text);
            const address = String(data.address || "");
            if (/^0x[0-9a-fA-F]+$/.test(address))
                root.targetWindow = address;
        } catch (e) {
            // No usable active window; copying still works as a fallback.
        }
    }

    function finishOpen() {
        if (!root.pendingOpen)
            return;
        root.pendingOpen = false;
        openingTimer.stop();
        root.query = "";
        root.selected = 0;
        root.category = "Recent";
        root.refreshResults();
        root.closing = false;
        closeTimer.stop();
        root.shown = true;
        root.reveal = 1;
        focusTimer.restart();
    }

    function open() {
        if (root.shown && !root.closing) {
            focusTimer.restart();
            return;
        }
        closeTimer.stop();
        root.pendingText = "";
        root.pendingOpen = true;
        root.targetWindow = "";
        root.probeClipboard();
        activeProbe.running = false;
        activeProbe.running = true;
        openingTimer.restart();
    }

    function close() {
        if (!root.shown || root.closing)
            return;
        root.closing = true;
        root.reveal = 0;
        focusTimer.stop();
        closeTimer.restart();
    }

    function toggle() {
        if (root.shown && !root.closing)
            root.close();
        else
            root.open();
    }

    Component.onCompleted: {
        root.loadRecent();
        root.loadClipboard();
        root.probeClipboard();
        Qt.callLater(function () {
            root.syncCategoryHighlight(false);
            root.syncGridHighlight(false);
        });
    }

    onQueryChanged: root.refreshResults()
    onCategoryChanged: {
        root.syncCategoryHighlight(true);
        root.refreshResults();
        root.syncGridHighlight(false);
    }
    onRecentChanged: root.refreshResults()
    onClipboardChanged: root.refreshResults()

    IpcHandler {
        target: "emoji"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
    }

    FileView {
        id: recentFile
        path: root.recentPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.loadRecent()
    }

    FileView {
        id: recentWriter
        path: root.recentPath
        blockWrites: false
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: clipboardFile
        path: root.clipboardPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.loadClipboard()
    }

    FileView {
        id: clipboardWriter
        path: root.clipboardPath
        blockWrites: false
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: activeProbe
        running: false
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null || true"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseWindowData(text);
                root.finishOpen();
            }
        }
    }

    Process {
        id: clipboardProbe
        running: false
        command: ["sh", "-c", "wl-paste -n -t text/plain 2>/dev/null || wl-paste -n 2>/dev/null || true"]

        stdout: StdioCollector {
            onStreamFinished: root.captureClipboard(text)
        }
    }

    Process {
        id: copyProcess
        running: false
    }

    Process {
        id: pasteProcess
        running: false
    }

    Timer {
        id: openingTimer
        interval: 180
        onTriggered: root.finishOpen()
    }

    Timer {
        id: closeTimer
        interval: Theme.motionFast + 20
        onTriggered: root.shown = false
    }

    Timer {
        id: clipboardTimer
        interval: 1200
        repeat: true
        running: true
        onTriggered: root.probeClipboard()
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: field.forceActiveFocus()
    }

    Timer {
        id: pasteTimer
        interval: Theme.motionFast + 70
        onTriggered: {
            const value = root.pendingText;
            root.pendingText = "";
            if (!value || root.targetWindow === "")
                return;
            const selector = "address:" + root.targetWindow;
            const expr = 'hl.dispatch(hl.dsp.focus({ window = "' + selector
                + '" })); hl.dispatch(hl.dsp.send_shortcut({ mods = "CTRL", key = "V", window = "'
                + selector + '" }))';
            pasteProcess.command = ["hyprctl", "eval", expr];
            pasteProcess.running = false;
            pasteProcess.running = true;
        }
    }

    PanelWindow {
        id: window

        visible: root.shown
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"
        focusable: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-emoji-surface"

        Loader {
            anchors.fill: card
            source: "SoftwareDimOverlay.qml"
            onLoaded: {
                item.screen = window.screen;
                item.radius = card.radius;
            }
        }
        WlrLayershell.keyboardFocus: root.shown
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card

            width: 560
            height: 470
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            radius: Theme.panelRadius
            color: Theme.panelFill(Theme.surface, "popups")
            border.width: 1
            border.color: Theme.border

            opacity: root.reveal
            scale: Theme.motionEnterScale
                + (1 - Theme.motionEnterScale) * root.reveal
            transform: Translate {
                y: -(1 - root.reveal) * Theme.motionEnterOffset
            }

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰈸"
                        font.family: Theme.font
                        font.pixelSize: 18
                        color: Theme.accent
                    }

                    TextField {
                        id: field

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: "Search emoji or clipboard history…"
                        placeholderTextColor: Theme.dim
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 14
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        leftPadding: 0
                        rightPadding: 0
                        background: Rectangle { color: "transparent" }

                        onTextChanged: {
                            root.query = text;
                            root.selected = 0;
                        }
                        onAccepted: {
                            if (root.results.length > 0)
                                root.insert(root.results[root.selected]);
                        }
                        Keys.onEscapePressed: {
                            if (root.query !== "") {
                                text = "";
                                root.query = "";
                            } else {
                                root.close();
                            }
                        }
                        Keys.onLeftPressed: root.move(-1)
                        Keys.onRightPressed: root.move(1)
                        Keys.onUpPressed: root.move(-root.columns)
                        Keys.onDownPressed: root.move(root.columns)
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_PageUp) {
                                root.move(-root.columns * 3);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                root.move(root.columns * 3);
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        text: root.results.length + (root.results.length === 1
                            ? " result" : " results")
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.dim
                    }

                    Text {
                        id: clearClipboardButton

                        visible: root.category === "Clipboard" && root.clipboard.length > 0
                        text: "clear"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: clearMouse.containsMouse ? Theme.accent : Theme.accentSoft

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearClipboard()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    contentWidth: categoryTrack.implicitWidth
                    contentHeight: 32
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        id: categoryTrack

                        width: categoryTrack.implicitWidth
                        height: 32
                        implicitWidth: categoryRow.implicitWidth
                        implicitHeight: categoryRow.implicitHeight

                        Rectangle {
                            x: root.categoryHighlightRect.x
                            y: root.categoryHighlightRect.y
                            width: root.categoryHighlightRect.width
                            height: root.categoryHighlightRect.height
                            radius: 8
                            color: Theme.active
                            border.width: 1
                            border.color: Theme.accent
                            visible: root.categoryHighlightVisible

                            Behavior on x {
                                enabled: root.categoryHighlightAnimate
                                NumberAnimation {
                                    duration: Theme.motionBase
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on y {
                                enabled: root.categoryHighlightAnimate
                                NumberAnimation {
                                    duration: Theme.motionBase
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on width {
                                enabled: root.categoryHighlightAnimate
                                NumberAnimation {
                                    duration: Theme.motionBase
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on height {
                                enabled: root.categoryHighlightAnimate
                                NumberAnimation {
                                    duration: Theme.motionBase
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Row {
                            id: categoryRow
                            spacing: 6
                            height: 32

                            Repeater {
                                id: categoryRepeater
                                model: root.categories

                                Rectangle {
                                    id: categoryChip

                                    required property string modelData

                                    width: chipLabel.implicitWidth + 20
                                    height: 26
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 8
                                    // Selected fill is the sliding highlight behind it.
                                    color: categoryChip.modelData === root.category
                                        ? "transparent"
                                        : (chipMouse.containsMouse
                                            ? Theme.hover : Theme.surfaceAlt)
                                    border.width: categoryChip.modelData === root.category ? 0 : 1
                                    border.color: Theme.border

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.motionFast }
                                    }
                                    Behavior on border.width {
                                        NumberAnimation { duration: Theme.motionFast }
                                    }

                                    Text {
                                        id: chipLabel
                                        anchors.centerIn: parent
                                        text: categoryChip.modelData
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                        color: categoryChip.modelData === root.category
                                            ? Theme.accentSoft : Theme.subtext

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.motionFast }
                                        }
                                    }

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.setCategory(categoryChip.modelData);
                                            field.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // Single selection highlight that slides between cells.
                    // It lives in the clipped viewport, not in the flickable
                    // content, so scrolling can never carry it off screen.
                    Rectangle {
                        x: root.gridHighlightRect.x
                        y: root.gridHighlightRect.y
                        width: root.gridHighlightRect.width
                        height: root.gridHighlightRect.height
                        radius: 10
                        color: Theme.active
                        border.width: 1
                        border.color: Theme.accent
                        visible: root.gridHighlightVisible

                        Behavior on x {
                            enabled: root.gridHighlightAnimate
                            NumberAnimation {
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            enabled: root.gridHighlightAnimate
                            NumberAnimation {
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on width {
                            enabled: root.gridHighlightAnimate
                            NumberAnimation {
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on height {
                            enabled: root.gridHighlightAnimate
                            NumberAnimation {
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    GridView {
                        id: grid

                        anchors.fill: parent
                        clip: true
                        model: root.results
                        cellWidth: Math.floor(width / root.columns)
                        cellHeight: root.category === "Clipboard" ? 48 : 62
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: root.selected

                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                property: "scale"
                                from: Theme.motionEnterScale
                                to: 1
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }
                        remove: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: Theme.motionFast
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                property: "scale"
                                to: Theme.motionEnterScale
                                duration: Theme.motionFast
                                easing.type: Easing.OutCubic
                            }
                        }
                        displaced: Transition {
                            NumberAnimation {
                                property: "y"
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }

                        delegate: Rectangle {
                            id: emojiCell

                            required property var modelData
                            required property int index

                            readonly property bool highlighted:
                                emojiCell.index === root.selected
                            readonly property bool clipboardEntry:
                                emojiCell.modelData.group === "Clipboard"

                            width: grid.cellWidth
                            height: grid.cellHeight
                            radius: 10
                            // Selected fill is the sliding highlight behind the cells.
                            color: !emojiCell.highlighted && cellMouse.containsMouse
                                ? Theme.hover : "transparent"
                            border.width: 0
                            border.color: "transparent"
                            scale: 1 - 0.04 * (cellMouse.containsPress ? 1 : 0)

                            Behavior on color {
                                ColorAnimation { duration: Theme.motionFast }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.motionFast
                                    easing.type: Easing.OutCubic
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 2
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    text: emojiCell.clipboardEntry
                                        ? emojiCell.modelData.preview
                                        : emojiCell.modelData.char
                                    font.family: emojiCell.clipboardEntry
                                        ? Theme.mono : "Noto Color Emoji"
                                    font.pixelSize: emojiCell.clipboardEntry ? 11 : 25
                                    horizontalAlignment: emojiCell.clipboardEntry
                                        ? Text.AlignLeft : Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    leftPadding: emojiCell.clipboardEntry ? 5 : 0
                                    rightPadding: emojiCell.clipboardEntry ? 5 : 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: emojiCell.modelData.name
                                    font.family: Theme.mono
                                    font.pixelSize: 8
                                    color: emojiCell.highlighted
                                        ? Theme.accentSoft : Theme.dim
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: {
                                    root.gridHoverPoint = grid.mapFromItem(
                                        cellMouse, mouseX, mouseY);
                                    root.selected = emojiCell.index;
                                }
                                onContainsMouseChanged: {
                                    const p = grid.mapFromItem(
                                        cellMouse, mouseX, mouseY);
                                    if (containsMouse) {
                                        const enteringGrid = root.gridHoverPoint.x < 0;
                                        root.gridHoverPoint = p;
                                        if (enteringGrid)
                                            root.selected = emojiCell.index;
                                    } else if (p.x < 0 || p.y < 0
                                        || p.x >= grid.width || p.y >= grid.height) {
                                        root.gridHoverPoint = Qt.point(-1, -1);
                                    }
                                }
                                onClicked: root.insert(emojiCell.modelData)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: root.query !== ""
                            ? "No emoji match “" + root.query + "”"
                            : (root.category === "Clipboard"
                                ? "Clipboard history is empty — copy some text to fill it"
                                : "No recent emoji yet — pick one to get started")
                        font.family: Theme.mono
                        font.pixelSize: 12
                        color: Theme.subtext
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "↑↓←→ navigate   ↵ insert   esc clear / close"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.dim
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "⌁ SUPER + ."
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.accentSoft
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: card
            anchors.margins: -1
            radius: card.radius + 1
            color: "#66000000"
            opacity: root.reveal
            z: -1
        }
    }
}
