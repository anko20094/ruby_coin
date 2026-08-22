// Entry point for the redesign. Deliberately separate from application.js:
// that bundle carries Bootstrap and Tom Select for the old theme and the admin,
// and the redesign's whole interaction budget is one ruby and click-to-load embeds.
//
// Built to app/assets/builds/theme.js by the esbuild glob in package.json.
import { Application } from "@hotwired/stimulus";
import RubyController from "./theme/ruby_controller";
import EmbedController from "./theme/embed_controller";

const application = Application.start();
application.register("ruby", RubyController);
application.register("embed", EmbedController);
