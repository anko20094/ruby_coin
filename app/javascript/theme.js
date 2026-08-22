// Entry point for the redesign. Deliberately separate from application.js:
// that bundle carries Bootstrap, TinyMCE and Tom Select for the old theme, and
// the redesign's whole interaction budget is one ruby.
//
// Built to app/assets/builds/theme.js by the esbuild glob in package.json.
import { Application } from "@hotwired/stimulus";
import RubyController from "./theme/ruby_controller";

const application = Application.start();
application.register("ruby", RubyController);
