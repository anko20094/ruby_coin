// The public site's bundle, built to app/assets/builds/theme.js. Kept apart from admin.js,
// which carries Turbo, Tom Select and the editor wiring no reader needs.
import { Application } from "@hotwired/stimulus";
import RubyController from "./theme/ruby_controller";
import EmbedController from "./theme/embed_controller";
import EntryPreviewController from "./theme/entry_preview_controller";
import FloatingRubyController from "./theme/floating_ruby_controller";
import DismissController from "./shared/dismiss_controller";
import ReadingProgressController from "./theme/reading_progress_controller";
import CopyController from "./theme/copy_controller";
import CaseRailController from "./theme/case_rail_controller";
import TrackJumpController from "./theme/track_jump_controller";
import NavController from "./theme/nav_controller";
import PaletteController from "./theme/palette_controller";
import QuoteCardController from "./theme/quote_card_controller";
import PasswordVisibilityController from "./theme/password_visibility_controller";
import PrintController from "./theme/print_controller";
import CardCollapseController from "./theme/card_collapse_controller";
import CountUpController from "./theme/count_up_controller";
import LiveSearchController from "./theme/live_search_controller";
import SearchClearController from "./theme/search_clear_controller";
import GemEggController from "./theme/gem_egg_controller";
import ListNavController from "./theme/list_nav_controller";
import "./theme/view_transitions";

// Which modifier the palette hint names: ⌘ on Apple platforms, Ctrl everywhere else.
const platform = navigator.userAgentData?.platform || navigator.platform || "";
document.documentElement.dataset.platform = /mac|iphone|ipad|ios/i.test(platform) ? "apple" : "other";

const application = Application.start();
application.register("ruby", RubyController);
application.register("embed", EmbedController);
application.register("entry-preview", EntryPreviewController);
application.register("floating-ruby", FloatingRubyController);
application.register("dismiss", DismissController);
application.register("reading-progress", ReadingProgressController);
application.register("copy", CopyController);
application.register("case-rail", CaseRailController);
application.register("track-jump", TrackJumpController);
application.register("nav", NavController);
application.register("palette", PaletteController);
application.register("quote-card", QuoteCardController);
application.register("password-visibility", PasswordVisibilityController);
application.register("print", PrintController);
application.register("card-collapse", CardCollapseController);
application.register("count-up", CountUpController);
application.register("live-search", LiveSearchController);
application.register("search-clear", SearchClearController);
application.register("gem-egg", GemEggController);
application.register("list-nav", ListNavController);
