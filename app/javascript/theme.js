// Entry point for the redesign. Deliberately separate from application.js:
// that bundle carries Bootstrap and Tom Select for the old theme and the admin,
// and the redesign's whole interaction budget is one ruby and click-to-load embeds.
//
// Built to app/assets/builds/theme.js by the esbuild glob in package.json.
import { Application } from "@hotwired/stimulus";
import RubyController from "./theme/ruby_controller";
import EmbedController from "./theme/embed_controller";
import FloatingRubyController from "./theme/floating_ruby_controller";
import DismissController from "./theme/dismiss_controller";
import ReadingProgressController from "./theme/reading_progress_controller";
import CopyController from "./theme/copy_controller";
import TrackJumpController from "./theme/track_jump_controller";
import NavController from "./theme/nav_controller";
import PaletteController from "./theme/palette_controller";
import QuoteCardController from "./theme/quote_card_controller";
import PasswordVisibilityController from "./theme/password_visibility_controller";

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
