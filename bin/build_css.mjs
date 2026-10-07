#!/usr/bin/env node
// The stylesheet entries, in one place. `yarn build:css` passes --style=compressed,
// `yarn build:css:dev` passes --watch; anything after the script name goes to sass as is.
import { spawn } from "node:child_process"

const ENTRIES = ["theme", "admin", "editor_content"]

const args = [
  ...ENTRIES.map((name) => `./app/assets/stylesheets/${name}.scss:./app/assets/builds/${name}.css`),
  "--no-source-map",
  "--load-path=node_modules",
  ...process.argv.slice(2),
]

const sass = spawn("sass", args, { stdio: "inherit", shell: process.platform === "win32" })
sass.on("exit", (code) => process.exit(code ?? 1))
