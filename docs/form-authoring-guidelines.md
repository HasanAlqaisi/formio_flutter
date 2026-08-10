# Form Authoring Guidelines — What Not to Put in a Form

> **For:** Form.io / Creatio form admins
> **Rule of thumb:** A form definition should be **pure logic** — data in, data
> out. Anything that reaches the outside world or draws its own UI belongs in a
> **component** the app provides, not in a form script.

Scripts here means the code you can type into a component's **Calculated Value**,
**Custom Conditional**, or **Custom Validation** boxes.

---

## ✅ Allowed — pure logic

These run everywhere (web, mobile, PDF, future renderers). Keep them.

- Math: `value = data.qty * data.price`
- Text building: `value = 'REF-' + code`
- Dates: comparing/formatting dates
- Conditions on **data**: `show = data.status === 'approved'`
- Validation on **the field's own value**: `valid = input >= 0`

If a snippet only transforms values, it's fine.

---

## ❌ Forbidden — reaching the outside world or the browser

If a snippet does any of the following, it will **silently stop working** outside
a web browser. Don't put it in a form script — ask for a **component** instead.

| # | Forbidden | Give-away keywords | Why it breaks |
|---|-----------|--------------------|---------------|
| 1 | **Network / API calls** | `fetch(`, `XMLHttpRequest` | The form now needs a live server + login session |
| 2 | **Reading/writing the page** | `document.`, `getElementById`, `.style`, `.innerHTML` | That HTML doesn't exist outside a browser |
| 3 | **Timers / polling** | `setInterval`, `setTimeout` | Background loops don't belong in a value calculation |
| 4 | **Browser storage** | `sessionStorage`, `localStorage`, `cookie` | The renderer can't provide it (tokens, ids) |
| 5 | **The URL / navigation** | `window.location`, `history` | Ties the form to a web address; false everywhere else |
| 6 | **Timing / performance APIs** | `performance.getEntriesByType` | Browser-only introspection |
| 7 | **Global scratch state** | `window.myFlag = …` | Fragile cross-field coordination via globals |

> ⚠️ Even *mentioning* these keywords can get a whole script disabled by the
> safety filter — so avoid them even as unused fallbacks.

---

## What to do instead

| If you were trying to… | Do this instead |
|------------------------|-----------------|
| Fill a dropdown from a server | Set the select's own **Data Source** to *URL* or *Resource* — the renderer loads it. Never `fetch(` in a script |
| Load other records from a server | Use a **DataSource** component |
| Show a live dashboard, map, upload, or signature | Ask for a **custom component** (the app builds it) |
| Read a token or task id from the session/URL | Have it passed in as **form data** and read it with a data condition |
| Share a value between fields | Use a **hidden field** as the shared value |
| Refresh something every N seconds | Belongs in a **component's lifecycle**, not a form script |

---

## Quick example

**❌ Wrong — a live widget hidden inside a calculation**

```js
// Calculated Value on a hidden field
setInterval(() => {
  fetch(api + '/timeline').then(r => r.json()).then(t => {
    document.getElementById('mileage').textContent = distance(t) + ' km';
  });
}, 30000);
value = '';   // it doesn't even set a value!
```

This needs a browser, a login, network access, and a timer — none of which exist
in a headless renderer, so it does nothing.

**✅ Right — the form just names a component**

```json
{ "type": "mileageWidget", "key": "mileage", "input": false }
```

The app provides the real `mileageWidget` (fetching, math, and UI in native code).
The form definition stays clean and portable.

---

## One-line summary

> **Values → form script. Anything else (network, UI, storage, timers, URL) →
> component.**
