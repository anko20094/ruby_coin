// The public site's bundle, built to app/assets/builds/theme.js. Kept apart from admin.js,
// which carries Turbo, Tom Select and the editor wiring no reader needs.
import { Application } from "@hotwired/stimulus";
import RubyController from "./theme/ruby_controller";
import EmbedController from "./theme/embed_controller";
import FloatingRubyController from "./theme/floating_ruby_controller";
import DismissController from "./shared/dismiss_controller";
import ReadingProgressController from "./theme/reading_progress_controller";
import CopyController from "./theme/copy_controller";
import TrackJumpController from "./theme/track_jump_controller";
import NavController from "./theme/nav_controller";
import PaletteController from "./theme/palette_controller";
import QuoteCardController from "./theme/quote_card_controller";
import PasswordVisibilityController from "./theme/password_visibility_controller";
import PrintController from "./theme/print_controller";

// Which modifier the palette hint names: ⌘ on Apple platforms, Ctrl everywhere else.
const platform = navigator.userAgentData?.platform || navigator.platform || "";
document.documentElement.dataset.platform = /mac|iphone|ipad|ios/i.test(platform) ? "apple" : "other";

const application = Application.start();
application.register("ruby", RubyController);
application.register("embed", EmbedController);
application.register("floating-ruby", FloatingRubyController);
application.register("dismiss", DismissController);
application.register("reading-progress", ReadingProgressController);
application.register("copy", CopyController);
application.register("track-jump", TrackJumpController);
application.register("nav", NavController);
application.register("palette", PaletteController);
application.register("quote-card", QuoteCardController);
application.register("password-visibility", PasswordVisibilityController);
application.register("print", PrintController);
