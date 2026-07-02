---
name: shadcn-component
description: "Add or customize a shadcn-ui component in a React + Tailwind repo. Use when the user asks to add a new UI primitive (dialog, popover, dropdown, combobox, etc.), extend an existing one in components/ui/, or troubleshoots a Radix / CVA styling issue."
license: Apache-2.0
metadata:
  author: Stanislav Pitsyk
  version: "0.1"
---

# Adding a shadcn-ui component

shadcn-ui is not a component library — it's a copy-in pattern. When you add a
component, its source lands inside your repo under `components/ui/` and you
own the file. Edit it freely; there's no "upgrade the dependency" path.

## Load-bearing rules

1. **Install with the shadcn CLI as your repo requires.** The canonical
   invocation is:
   ```sh
   npx shadcn@latest add <component>
   ```
   If the repo forbids running `npm` / `npx` on the host (common in
   Docker-first workflows), route through the project's dev/deps
   container as documented in its README — for example:
   ```sh
   docker exec <dev-container> npx shadcn@latest add <component>
   # or open an ephemeral deps container per the repo's convention,
   # then copy the generated file back to the host.
   ```

2. **Aliases are fixed by `components.json`.** shadcn expects:
   - UI primitives → `@/components/ui`
   - Feature components → `@/components/<feature>`
   - Utils → `@/lib/utils` (this is where `cn()` lives)
   - Hooks → `@/hooks`

   Don't move these directories or the shadcn CLI stops resolving on the
   next install.

3. **Prefer composing existing shadcn primitives over installing a new
   Radix package.** Before adding a `@radix-ui/*` dependency directly,
   check `components/ui/` — a wrapper probably already exists (Dialog,
   Popover, DropdownMenu, Select, Tabs, etc. all ship as shadcn primitives).

4. **Use `cn()` for conditional classnames.** Every `ui/` file imports it:
   ```ts
   import { cn } from "@/lib/utils";
   ```
   Don't reach for `clsx` directly, and don't hand-concatenate class
   strings — `cn()` is `clsx` composed with `tailwind-merge`, which
   deduplicates conflicting Tailwind classes.

5. **`className` must come last in the merge.** Given
   `cn("bg-red-500", className)`, a consumer passing
   `className="bg-blue-500"` wins. The reverse order silently ignores
   consumer overrides.

## When customizing an existing ui/ component

Edit the file in place. Don't create `MyButton.tsx` that wraps `Button`
unless the wrapper adds real behavior (loading state, i18n, telemetry,
form-integration) — otherwise the codebase grows two ways to do the same
thing and future readers can't tell which is canonical.

## Styling conventions

- **Colors come from CSS variables** mapped in `tailwind.config.ts`:
  `bg-background`, `text-foreground`, `border-input`, `bg-primary`,
  `text-primary-foreground`, etc. Prefer these over literal palette
  classes (`bg-slate-900`) because dark mode is wired through the
  variables. Literal colors won't auto-adjust.

- **Spacing** — match the neighborhood. If the surrounding file uses
  `p-4` and `gap-2`, don't introduce `p-3.5`. Consistency within a file
  matters more than local aesthetic preference.

- **Dark mode** is `class`-based (via `next-themes` or Tailwind's
  `dark` class strategy). Any color set with a literal Tailwind palette
  will NOT auto-adjust — use the CSS variables or an explicit `dark:`
  variant.

## After adding a component

1. Verify the import path in the consumer uses the repo's `components`
   alias (e.g. `@/components/ui/<name>`) from `components.json`, not a
   deep relative path.
2. Verify it visually — running app, Storybook, or preview — in both
   light and dark modes if your app supports them.
3. If the component takes user-visible text and the project uses i18n
   (`react-i18next`, `react-intl`, etc.), wire the string through your
   `t(...)` helper immediately — linters usually don't catch hardcoded
   English.

## Reference material

- **shadcn-ui docs** — <https://ui.shadcn.com/docs>
- **shadcn CLI reference** — <https://ui.shadcn.com/docs/cli>
- **`components.json` spec** — <https://ui.shadcn.com/docs/components-json>
- **`tailwind-merge` (backing `cn()`)** — <https://github.com/dcastil/tailwind-merge>
- **`class-variance-authority` (variant helpers)** — <https://cva.style/>
- **Radix UI primitives** — <https://www.radix-ui.com/primitives>
