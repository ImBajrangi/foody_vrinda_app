# Foody Vrinda App Rules & Guidelines

These are rules that must be followed without exception by all developers and AI agents working on the `foody_vrinda_app` codebase.

---

## 1. Dynamic Style Linting Rule

* **Guideline**: Do not use compile-time constants (`const`) for any widget tree styling that references dynamic theme attributes (e.g., brand colors, accent variations). 
* **Reason**: Using `const` on widgets containing dynamic attributes like `AppTheme.primaryOrange` results in `invalid_constant` static analysis and compile errors because these values change dynamically when the user switches visual atmospheres at runtime.

---

## 2. Explicit Type Casting for Iterative Map Lists

* **Guideline**: Always cast dynamic or object map properties explicitly (e.g., `(item['key'] as String)`) inside maps used to generate rows, columns, or grids.
* **Reason**: Prevents Dart static analyzer errors regarding undefined methods (such as `substring` or `toLowerCase`) when attributes are implicitly treated as `Object?` instead of their correct runtime type.
