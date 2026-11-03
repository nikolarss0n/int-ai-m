# TypeScript Cards: 45 questions and answers

**Original four-choice cards converted from the 20 collected TypeScript mock-interview prompts.** Compound prompts were split into single-answer questions. The app loads this deck for the TypeScript Cards role.

| Topic | Cards |
| --- | ---: |
| TypeScript | 45 |

## Cards

## TypeScript

### 1. TypeScript vs JavaScript

`ts-cards-01-1`

Which statement best describes the relationship between TypeScript and JavaScript?

- **A.** TypeScript is a superset of JavaScript that adds static types checked before the code runs.
- **B.** TypeScript is a subset of JavaScript that omits the dynamic features a type checker cannot model.
- **C.** TypeScript is a separate language with its own runtime that executes annotated source directly.
- **D.** TypeScript is a JavaScript library that validates argument types each time a function is called.

<details>
<summary>Reveal answer</summary>

**A. TypeScript is a superset of JavaScript that adds static types checked before the code runs.**

TypeScript extends JavaScript syntax with optional static type annotations that the compiler checks ahead of execution, so any valid JavaScript program is also a valid TypeScript program.

- **B:** Nothing is removed: every valid JavaScript file is already a valid TypeScript file.
- **C:** There is no TypeScript runtime; the compiler emits plain JavaScript for an existing engine.
- **D:** It is a language and compiler, not a runtime validation library added to a program.

</details>

### 2. TypeScript vs JavaScript

`ts-cards-01-2`

What happens to TypeScript type annotations when the project is compiled and run in Node.js or a browser?

- **A.** They are compiled into runtime guards that throw when a value has the wrong type.
- **B.** They are erased during compilation, so no type information survives into the running program.
- **C.** They are attached to each value as metadata that the runtime `typeof` operator can read back.
- **D.** They are kept in the emitted output and verified the first time each function is called.

<details>
<summary>Reveal answer</summary>

**B. They are erased during compilation, so no type information survives into the running program.**

The compiler removes annotations and emits plain JavaScript, so static types constrain the source but provide no protection against data that arrives at runtime.

- **A:** The compiler emits no checks; annotations produce no runtime code at all.
- **C:** Runtime `typeof` reports only JavaScript's own primitive tags, never a declared TypeScript type.
- **D:** The emitted output is ordinary JavaScript with the annotations stripped, not a deferred check.

</details>

### 3. any, unknown, never

`ts-cards-02-1`

You assign a value typed `unknown` to a variable typed `string`. What does the compiler do?

- **A.** It accepts the assignment, because `unknown` is assignable to every other type.
- **B.** It accepts the assignment but treats the variable as possibly `undefined` afterwards.
- **C.** It rejects the assignment until the value is narrowed or asserted to `string`.
- **D.** It rejects the assignment and also rejects narrowing, since `unknown` can never be refined.

<details>
<summary>Reveal answer</summary>

**C. It rejects the assignment until the value is narrowed or asserted to `string`.**

`unknown` is the safe counterpart of `any`: any value can be stored in it, but it is assignable only to `unknown` and `any`, so a check or assertion has to come first.

- **A:** That describes `any`; `unknown` is assignable only to `unknown` and `any`.
- **B:** No implicit widening happens; the assignment itself is what the checker rejects.
- **D:** Narrowing is exactly how `unknown` is meant to be consumed, through `typeof` or a predicate.

</details>

### 4. any, unknown, never

`ts-cards-02-2`

A `switch` handles every member of a discriminated union. What type does the value have in the `default` branch?

- **A.** `undefined`, because no case produced a value for that branch.
- **B.** The original union, because narrowing does not reach the `default` branch.
- **C.** `unknown`, because the compiler stops tracking the type after the last case.
- **D.** `never`, because every union member has already been handled.

<details>
<summary>Reveal answer</summary>

**D. `never`, because every union member has already been handled.**

Each handled case subtracts a member, so an exhaustive switch leaves `never`; assigning that value to a `never`-typed local turns a future unhandled variant into a compile error.

- **A:** Narrowing describes which union members remain, and it never introduces `undefined`.
- **B:** Control-flow analysis does reach `default` and subtracts every member handled above it.
- **C:** Tracking continues; the checker knows precisely which members were eliminated.

</details>

### 5. any, unknown, never

`ts-cards-02-3`

What is the main cost of annotating a value as `any` rather than `unknown`?

- **A.** `any` switches off checking for that value, so bad property access and calls pass silently.
- **B.** `any` blocks narrowing, so the value can never be used without an explicit assertion.
- **C.** `any` triggers a runtime conversion that can change the shape of the stored value.
- **D.** `any` is rejected under `strict`, so the file quietly falls back to loose checking.

<details>
<summary>Reveal answer</summary>

**A. `any` switches off checking for that value, so bad property access and calls pass silently.**

`any` disables type checking for the value and everything derived from it, while `unknown` keeps the value opaque until code proves what it is.

- **B:** `any` allows every operation; it is `unknown` that requires narrowing before use.
- **C:** Annotations are erased on emit, so no conversion of any kind happens at runtime.
- **D:** `strict` only bans *implicit* `any`; an explicit `any` annotation stays legal.

</details>

### 6. Interfaces vs Type Aliases

`ts-cards-03-1`

Which capability do interfaces have that type aliases do not?

- **A.** Describing an object shape whose members are optional or marked `readonly`.
- **B.** Being adopted by a class through an `implements` clause.
- **C.** Being declared twice under one name so that the two declarations merge.
- **D.** Being used as the type of a function parameter or of a return value.

<details>
<summary>Reveal answer</summary>

**C. Being declared twice under one name so that the two declarations merge.**

Two interfaces with the same name in a scope combine their members, which is how declaration files augment library types; a repeated type alias is a duplicate-identifier error.

- **A:** Type aliases express optional and `readonly` members exactly as interfaces do.
- **B:** A class can implement a type alias of object type just as well as an interface.
- **D:** Both forms name a type and may appear in any type position.

</details>

### 7. Interfaces vs Type Aliases

`ts-cards-03-2`

Which type can be expressed with a `type` alias but not with an `interface` declaration?

- **A.** `type Id = string | number`, a union of two primitive types.
- **B.** `type Point = { x: number; y: number }`, an object with two members.
- **C.** `type Box<T> = { value: T }`, a generic container with one parameter.
- **D.** `type Handler = (event: string) => void`, a single call signature.

<details>
<summary>Reveal answer</summary>

**A. `type Id = string | number`, a union of two primitive types.**

Interfaces can only describe object, callable, or constructible shapes, so unions, conditional types, and mapped types all require a type alias.

- **B:** An interface states this shape directly, so both forms work here.
- **C:** Interfaces take type parameters too, so a generic interface is equivalent.
- **D:** An interface can carry a call signature, which expresses the same function type.

</details>

### 8. Structural Typing

`ts-cards-03-3`

A function parameter is typed `interface Point { x: number; y: number }`. Why does a variable of type `{ x: number; y: number; z: number }` pass?

- **A.** Because extra properties are ignored only when the variable is declared with `let`.
- **B.** Because the compiler strips unknown properties before the call so the shapes match.
- **C.** Because the variable was declared before the interface, so it is treated as compatible.
- **D.** Because TypeScript compares shapes rather than names, and the value has every required member.

<details>
<summary>Reveal answer</summary>

**D. Because TypeScript compares shapes rather than names, and the value has every required member.**

Assignability depends on having the required members, not on naming a base type; excess property checks apply only to a fresh object literal written directly at the call site.

- **A:** The declaration keyword plays no part in assignability between object types.
- **B:** Nothing is stripped; the argument is passed exactly as written.
- **C:** Declaration order is irrelevant to how the checker compares two types.

</details>

### 9. Unions and Intersections

`ts-cards-04-1`

Given `type Value = string | number`, which members can be used on a `Value` before any narrowing?

- **A.** Every member of `string` and every member of `number`, since one of them is present.
- **B.** No members at all, because a union declares no surface of its own.
- **C.** Only the members of `string`, because it is written first in the union.
- **D.** Only members that `string` and `number` both declare, such as `toString`.

<details>
<summary>Reveal answer</summary>

**D. Only members that `string` and `number` both declare, such as `toString`.**

A union value may be any of its members, so only the members common to all of them are accessible until a narrowing check selects one branch.

- **A:** The checker cannot know which branch holds, so branch-specific members stay unavailable.
- **B:** Shared members such as `toString` remain available on every member of the union.
- **C:** Order carries no meaning in a union type; neither member is preferred.

</details>

### 10. Unions and Intersections

`ts-cards-04-2`

What does the intersection `A & B` describe when `A` and `B` are object types?

- **A.** A value that satisfies both shapes at once, carrying the members declared by each.
- **B.** A value that satisfies either shape, with the compiler choosing one at each use site.
- **C.** A value holding only the members that `A` and `B` happen to declare in common.
- **D.** A value of `A` whose conflicting members are replaced by the ones declared in `B`.

<details>
<summary>Reveal answer</summary>

**A. A value that satisfies both shapes at once, carrying the members declared by each.**

An intersection requires every member of `A` and every member of `B`, and a property declared with incompatible primitive types in each collapses to `never` rather than being overwritten.

- **B:** That is a union; an intersection demands both sets of members simultaneously.
- **C:** Common members are what a *union* exposes; an intersection keeps all of them.
- **D:** No overriding happens; a member with incompatible types reduces to `never`.

</details>

### 11. Narrowing

`ts-cards-05-1`

A parameter is typed `string | null`. Why does `if (typeof value === "object")` narrow it to `null`?

- **A.** Because the compiler models `null` as an empty object type under every strict setting.
- **B.** Because `typeof null` evaluates to `"object"` in JavaScript, and the checker models that.
- **C.** Because `typeof` cannot tell `null` from `string`, so it falls back to the nullable branch.
- **D.** Because narrowing by `typeof` always removes primitives first and keeps what remains.

<details>
<summary>Reveal answer</summary>

**B. Because `typeof null` evaluates to `"object"` in JavaScript, and the checker models that.**

`typeof null` has returned `"object"` since the earliest JavaScript engines, so `null` is the only member of that union which matches the check.

- **A:** `null` is its own primitive type, not an object type, in the type system.
- **C:** The operator distinguishes them cleanly: a string reports `"string"`.
- **D:** Each `typeof` check selects the members matching that specific tag, with no fixed ordering.

</details>

### 12. Narrowing

`ts-cards-05-2`

Which check narrows `type Shape = { radius: number } | { side: number }` to the first member?

- **A.** `if (shape instanceof Object)`
- **B.** `if (typeof shape.radius === "number")`
- **C.** `if ("radius" in shape)`
- **D.** `if (shape.radius !== undefined)`

<details>
<summary>Reveal answer</summary>

**C. `if ("radius" in shape)`**

The `in` operator is a narrowing construct, so testing for a property that appears in exactly one member selects that member without touching the value first.

- **A:** Both members are objects, so this test eliminates nothing.
- **B:** Reading `radius` is an error before narrowing, because it is missing from the other member.
- **D:** This also reads `radius` up front, which the checker rejects on the unnarrowed union.

</details>

### 13. Type Guards

`ts-cards-06-1`

What does the return type `value is User` on a boolean-returning function tell the compiler?

- **A.** That the function throws whenever the argument turns out not to be a `User`.
- **B.** That callers may treat the argument as a `User` inside the true branch of the check.
- **C.** That the function converts the argument into a `User` before handing it back.
- **D.** That the compiler generates the required property checks inside the function body.

<details>
<summary>Reveal answer</summary>

**B. That callers may treat the argument as a `User` inside the true branch of the check.**

A type predicate makes a user-defined function participate in narrowing, so the compiler takes its word and the body has to genuinely inspect the value.

- **A:** A predicate returns `false` for a mismatch; throwing is what an assertion signature does.
- **C:** Predicates never transform values; the returned boolean is the only result.
- **D:** The body must implement the checks itself, and the compiler simply trusts the result.

</details>

### 14. Type Guards

`ts-cards-06-2`

How does an assertion signature such as `function assertUser(v: unknown): asserts v is User` behave?

- **A.** It narrows the value only inside the function body and leaves the caller unaffected.
- **B.** It tags the checked value at runtime so later checks of the same value can be skipped.
- **C.** It removes the need for the function to examine the value at runtime at all.
- **D.** It narrows the value for the rest of the enclosing scope rather than inside a branch.

<details>
<summary>Reveal answer</summary>

**D. It narrows the value for the rest of the enclosing scope rather than inside a branch.**

An assertion function narrows from the call onward and must throw otherwise; it has to be invoked through an explicitly typed identifier rather than an inferred `const`.

- **A:** The whole point of the signature is the effect it has on the caller's flow analysis.
- **B:** No tag is written; the emitted output is a plain function call.
- **C:** The body must still throw on a mismatch, or the narrowing becomes a lie.

</details>

### 15. Generics

`ts-cards-07-1`

Why is `function first<T>(items: T[]): T` preferable to `function first(items: any[]): any`?

- **A.** It runs faster, because generic code is specialized for each element type at build time.
- **B.** It preserves the link between argument and result, so callers keep the element type.
- **C.** It forbids calling the function with arrays of primitives, which are unsafe to index.
- **D.** It checks the element type at runtime and throws when the array is heterogeneous.

<details>
<summary>Reveal answer</summary>

**B. It preserves the link between argument and result, so callers keep the element type.**

A type parameter relates the input to the output, so `first(users)` returns `User` instead of `any` and later property access stays checked.

- **A:** Generics are erased on emit and produce exactly the same JavaScript.
- **C:** An unconstrained type parameter accepts primitives just as readily as objects.
- **D:** No runtime check exists; the guarantee is entirely static.

</details>

### 16. Generics

`ts-cards-07-2`

What does the constraint in `function get<T, K extends keyof T>(obj: T, key: K): T[K]` guarantee?

- **A.** That `obj` has at least one property, because `keyof` rejects an empty object type.
- **B.** That `key` is verified against `obj` at runtime before the property is read.
- **C.** That `T` must be an interface rather than a class instance type or a type alias.
- **D.** That `key` is one of `T`'s property names and the result is that property's type.

<details>
<summary>Reveal answer</summary>

**D. That `key` is one of `T`'s property names and the result is that property's type.**

`K extends keyof T` limits the argument to the object's known names, and the indexed access `T[K]` returns exactly the type of the property that was selected.

- **A:** `keyof {}` is simply `never`; an empty object type is still accepted.
- **B:** Constraints are erased on emit, so nothing is verified while the code runs.
- **C:** Any object type may be substituted, whatever syntax declared it.

</details>

### 17. keyof, typeof, Indexed Access

`ts-cards-08-1`

For `interface User { id: number; name: string }`, what is `keyof User`?

- **A.** The union `"id" | "name"` of the declared property names.
- **B.** The union `number | string` of the declared property types.
- **C.** The tuple `["id", "name"]` holding the names in declaration order.
- **D.** The type `string`, because every property key of an object is a string.

<details>
<summary>Reveal answer</summary>

**A. The union `"id" | "name"` of the declared property names.**

`keyof` produces a union of a type's literal key types, and that union is what lets generic property accessors reject names the object does not have.

- **B:** Those are the value types, which an indexed access rather than `keyof` produces.
- **C:** `keyof` yields an unordered union, never a positional tuple.
- **D:** The result keeps the literal names, which is what makes key parameters checkable.

</details>

### 18. keyof, typeof, Indexed Access

`ts-cards-08-2`

Given `const config = { retries: 3 }`, what does `typeof config` mean in a type position?

- **A.** The string `"object"`, matching what the runtime operator would produce.
- **B.** The inferred type of the `config` value, here `{ retries: number }`.
- **C.** A startup assertion that fails when `config` has not been initialized.
- **D.** The union of the types of `config`'s properties, here just `number`.

<details>
<summary>Reveal answer</summary>

**B. The inferred type of the `config` value, here `{ retries: number }`.**

In a type position `typeof` is the type query operator: it names the inferred type of an existing value, which keeps derived types in step with the value itself.

- **A:** The runtime operator is unrelated; in a type position `typeof` queries the declared type.
- **C:** Type queries emit nothing and cannot fail while the program runs.
- **D:** That would need an indexed access such as `(typeof config)[keyof typeof config]`.

</details>

### 19. keyof, typeof, Indexed Access

`ts-cards-08-3`

For `interface Res { data: { items: string[] } }`, which type expression evaluates to `string`?

- **A.** `keyof Res["data"]["items"]`
- **B.** `Res["data"]["items"]`
- **C.** `Res["data"].items.element`
- **D.** `Res["data"]["items"][number]`

<details>
<summary>Reveal answer</summary>

**D. `Res["data"]["items"][number]`**

Indexed access types chain through property names, and indexing an array or tuple type with `number` produces the type of its elements.

- **A:** This yields the array's own key and method names, not its element type.
- **B:** This stops one step early and evaluates to `string[]`.
- **C:** Dotted member access and an invented `element` key are not type-level syntax.

</details>

### 20. Optional Properties and Chaining

`ts-cards-09-1`

Under `strict`, how does `interface A { name?: string }` differ from `interface B { name: string | undefined }`?

- **A.** They are identical, because `?` is only shorthand for adding `undefined` to the type.
- **B.** `B` may omit the property, while `A` must always spell out an explicit `undefined`.
- **C.** `A` may omit the property, while `B` must include it even when the value is `undefined`.
- **D.** `A` additionally permits `null`, while `B` permits only the value `undefined`.

<details>
<summary>Reveal answer</summary>

**C. `A` may omit the property, while `B` must include it even when the value is `undefined`.**

The `?` modifier makes the property optional at the construction site, so it may be left out, whereas a required property typed `| undefined` must still be written.

- **A:** The modifier also governs whether the property may be left out entirely.
- **B:** This reverses the two: the `?` modifier belongs to `A`.
- **D:** Neither form admits `null` unless `null` is written into the type.

</details>

### 21. Optional Properties and Chaining

`ts-cards-09-2`

What is the type of `user?.address?.city` when `address` is optional and `city` is a `string`?

- **A.** `string`, because optional chaining removes `undefined` from the final result.
- **B.** `string | null`, because a missing link in the chain evaluates to `null`.
- **C.** `unknown`, because the compiler cannot follow a chain of optional accesses.
- **D.** `string | undefined`, because the chain yields `undefined` when a link is nullish.

<details>
<summary>Reveal answer</summary>

**D. `string | undefined`, because the chain yields `undefined` when a link is nullish.**

Optional chaining short-circuits to `undefined` as soon as a link is `null` or `undefined`, so the result type always includes `undefined`.

- **A:** Chaining introduces `undefined` into the result rather than removing it.
- **B:** A short-circuited chain produces `undefined`, even when the missing link held `null`.
- **C:** The checker follows each link and computes a precise result type.

</details>

### 22. null and undefined

`ts-cards-10-1`

What does enabling `strictNullChecks` change about `null` and `undefined`?

- **A.** They become assignable only to their own types and to unions that list them.
- **B.** They merge into one nullish type so the two values may be used interchangeably.
- **C.** They are dropped from the type system and reported as errors wherever they appear.
- **D.** They stay assignable everywhere, but each use site gains an implicit runtime check.

<details>
<summary>Reveal answer</summary>

**A. They become assignable only to their own types and to unions that list them.**

Without the flag `null` and `undefined` belong to every type; with it they must be written into the type, so the checker can demand a guard before the value is used.

- **B:** They stay distinct types; the flag changes assignability, not their identity.
- **C:** Both remain usable; they simply have to appear in the declared type.
- **D:** The flag adds no emitted code, only stricter static assignability rules.

</details>

### 23. null and undefined

`ts-cards-10-2`

How does `value ?? "fallback"` differ from `value || "fallback"`?

- **A.** `??` falls back for any falsy value, while `||` falls back only for `undefined`.
- **B.** `??` evaluates both operands eagerly, while `||` short-circuits on the first.
- **C.** `??` falls back only for `null` or `undefined`, while `||` also falls back for `0` and `""`.
- **D.** `??` works only on optional properties, while `||` works on any expression at all.

<details>
<summary>Reveal answer</summary>

**C. `??` falls back only for `null` or `undefined`, while `||` also falls back for `0` and `""`.**

Nullish coalescing checks only for `null` and `undefined`, so meaningful falsy values such as `0`, `""`, and `false` pass through untouched.

- **A:** This inverts the two operators' behavior.
- **B:** Both operators short-circuit and skip the right operand when it is not needed.
- **D:** Both operators apply to any expression, whatever declared the operand.

</details>

### 24. Enums and Literal Unions

`ts-cards-11-1`

What does `enum Level { Low, High }` emit in the compiled JavaScript?

- **A.** Nothing, because the compiler erases enums the way it erases type annotations.
- **B.** A frozen array holding the member names in their declaration order.
- **C.** An object carrying both name-to-value and value-to-name entries.
- **D.** A class whose static members expose the numeric values.

<details>
<summary>Reveal answer</summary>

**C. An object carrying both name-to-value and value-to-name entries.**

A numeric enum emits a runtime object with a reverse mapping, so `Level.Low` is `0` and `Level[0]` is `"Low"`; string enums emit only the forward direction.

- **A:** Only `const enum` and ambient declarations avoid emitting code; a plain enum does not.
- **B:** The emitted value is an object keyed by name, and it is not frozen.
- **D:** The emitted helper is a plain object built inside an IIFE, not a class.

</details>

### 25. Enums and Literal Unions

`ts-cards-11-2`

Which alternative to `enum Status { Active = "active", Done = "done" }` gives the same checking with no emitted code?

- **A.** `const Status = { Active: "active", Done: "done" }`, a plain object of constants.
- **B.** `declare enum Status { Active, Done }`, an ambient enum declaration.
- **C.** `class Status { static Active = "active"; static Done = "done" }`, a static holder.
- **D.** `type Status = "active" | "done"`, a union of string literal types.

<details>
<summary>Reveal answer</summary>

**D. `type Status = "active" | "done"`, a union of string literal types.**

A union of string literal types disappears at build time while still constraining values, which is why it is the usual replacement for a string enum.

- **A:** This object is emitted and lives in the bundle just as the enum's object would.
- **B:** It emits nothing but promises a runtime enum exists elsewhere, so something must supply it.
- **C:** A class is emitted too, and it adds a constructor the values never need.

</details>

### 26. Tuples

`ts-cards-12-1`

How does the type `[string, number]` differ from `(string | number)[]`?

- **A.** The tuple stores its elements contiguously, while the array type is a linked structure.
- **B.** The tuple fixes the length and the type at each position, while the array allows any length or order.
- **C.** The tuple is immutable, while the array type additionally permits `push` and `pop`.
- **D.** The tuple is checked at runtime, while the array type is checked only during compilation.

<details>
<summary>Reveal answer</summary>

**B. The tuple fixes the length and the type at each position, while the array allows any length or order.**

A tuple is an array type with a known length and a declared type per index, which is what makes destructuring such as `const [name, age] = pair` type-safe.

- **A:** Both are ordinary JavaScript arrays at runtime with identical storage.
- **C:** A tuple is mutable unless it is marked `readonly` or built with a const assertion.
- **D:** Neither form produces a runtime check, because both are erased on emit.

</details>

### 27. Function Overloads

`ts-cards-13-1`

In an overloaded function, what is the role of the implementation signature?

- **A.** It is the fallback that callers receive when none of the overloads match.
- **B.** It is visible only inside the function and cannot be called from outside.
- **C.** It is merged with the overloads into a single union signature offered to callers.
- **D.** It is the signature used whenever the function is passed as a callback argument.

<details>
<summary>Reveal answer</summary>

**B. It is visible only inside the function and cannot be called from outside.**

The implementation signature has to be compatible with every overload, but it is not part of the callable surface, so its broader parameter types stay private.

- **A:** A call matching no overload is an error; there is no fallback signature.
- **C:** No merging occurs; the overload list is the public surface as written.
- **D:** A callback position resolves against the overloads exactly like a direct call.

</details>

### 28. Function Overloads

`ts-cards-13-2`

How does the compiler decide which overload applies to a particular call?

- **A.** It tries the declared overloads from top to bottom and takes the first that matches.
- **B.** It scores every overload and picks the one requiring the fewest parameter conversions.
- **C.** It selects the overload whose return type fits the surrounding expression.
- **D.** It combines all matching overloads and hands back the union of their return types.

<details>
<summary>Reveal answer</summary>

**A. It tries the declared overloads from top to bottom and takes the first that matches.**

Overload resolution walks the declarations in order and stops at the first match, so more specific signatures must be declared before broader ones.

- **B:** There is no scoring pass, and the type system performs no implicit conversions.
- **C:** Return types do not drive overload selection; the arguments do.
- **D:** Exactly one overload is chosen, and its return type is the result.

</details>

### 29. Literal Types

`ts-cards-14-1`

Why does `let mode = "dark"` infer `string` while `const mode = "dark"` infers `"dark"`?

- **A.** Because `const` declarations are hoisted differently and so retain their initializer type.
- **B.** Because a mutable binding is widened to the primitive type it might later hold.
- **C.** Because `let` bindings are re-inferred on each assignment and lose the literal type.
- **D.** Because string literal types can appear only inside type aliases, never in inference.

<details>
<summary>Reveal answer</summary>

**B. Because a mutable binding is widened to the primitive type it might later hold.**

Literal widening applies to mutable locations: a `let` may be reassigned to any string, so the literal widens, while an immutable `const` keeps the narrow literal type.

- **A:** Hoisting affects the binding's lifetime, not the type the checker infers for it.
- **C:** The declared type is fixed once at the declaration, not recomputed per assignment.
- **D:** Literal types are inferred routinely, for example for every `const` string.

</details>

### 30. Discriminated Unions

`ts-cards-14-2`

What makes a union of object types a discriminated union?

- **A.** Every member declares the same property names, differing only in their value types.
- **B.** Every member is declared as an interface rather than as a type alias.
- **C.** Every member shares a property whose type is a different literal in each member.
- **D.** Every member is tagged at runtime by the compiler with a hidden kind field.

<details>
<summary>Reveal answer</summary>

**C. Every member shares a property whose type is a different literal in each member.**

A common property with distinct literal types lets the checker map one equality test to exactly one member, which is what enables `switch (shape.kind)` narrowing.

- **A:** Identical key sets do not help; the checker needs one property with distinct literals.
- **B:** The declaring syntax is irrelevant to how narrowing works on the union.
- **D:** The discriminant is an ordinary property the author writes, not injected by the compiler.

</details>

### 31. Mapped Types

`ts-cards-15-1`

What does `type Concrete<T> = { [K in keyof T]-?: T[K] }` do?

- **A.** It strips the optional modifier from every property of `T`.
- **B.** It removes every property of `T` whose declared type includes `undefined`.
- **C.** It makes every property of `T` both optional and `readonly` at the same time.
- **D.** It renames each optional property of `T` by removing a trailing marker character.

<details>
<summary>Reveal answer</summary>

**A. It strips the optional modifier from every property of `T`.**

A mapped type can add or subtract the `?` and `readonly` modifiers, and the `-?` prefix removes optionality across every mapped key.

- **B:** Properties are kept; only the `?` modifier is affected by the mapping.
- **C:** That would be written `+?` together with `readonly`, the opposite of this mapping.
- **D:** Renaming requires an `as` clause in the key position, which this mapping lacks.

</details>

### 32. Conditional Types

`ts-cards-15-2`

Why does `type ToArray<T> = T extends unknown ? T[] : never` give `string[] | number[]` for `string | number`?

- **A.** Because a conditional type always evaluates both branches and unions the outcomes.
- **B.** Because a conditional over a naked type parameter distributes across the union members.
- **C.** Because `unknown` on the right side forces the compiler to expand the union first.
- **D.** Because array types are covariant, so `(string | number)[]` simplifies to that union.

<details>
<summary>Reveal answer</summary>

**B. Because a conditional over a naked type parameter distributes across the union members.**

When the checked type is a bare type parameter the conditional distributes over each union member; wrapping it as `[T] extends [unknown]` turns distribution off.

- **A:** Only one branch is taken per check; the union comes from distribution, not both branches.
- **C:** Distribution depends on the checked type being a bare parameter, not on what it is compared with.
- **D:** Covariance does not rewrite an array of a union into a union of arrays.

</details>

### 33. Conditional Types

`ts-cards-15-3`

What does `infer` do in `type Unwrap<T> = T extends Promise<infer U> ? U : T`?

- **A.** It asserts that `T` really is a promise and reports an error when it is not.
- **B.** It defers the conditional until the type is referenced at a concrete call site.
- **C.** It widens the matched type argument to its nearest primitive supertype.
- **D.** It introduces a type variable bound to whatever the pattern matched, here the resolved value.

<details>
<summary>Reveal answer</summary>

**D. It introduces a type variable bound to whatever the pattern matched, here the resolved value.**

`infer U` captures part of the matched type so the true branch can use it, which is the mechanism behind utility types such as `ReturnType` and `Awaited`.

- **A:** A failed match simply takes the false branch; no error is produced.
- **B:** Evaluation is deferred by an unresolved type parameter, not by the `infer` keyword.
- **C:** The captured type is used exactly as matched, with no widening applied.

</details>

### 34. Utility Types

`ts-cards-16-1`

What is the difference between `Pick<User, "id">` and `Omit<User, "id">`?

- **A.** `Pick` keeps only the listed keys, while `Omit` keeps everything except them.
- **B.** `Pick` keeps the listed keys as required, while `Omit` turns them optional.
- **C.** `Pick` copies the properties by value, while `Omit` references the original type.
- **D.** `Pick` errors on a key that is missing, while `Omit` errors on a key that exists.

<details>
<summary>Reveal answer</summary>

**A. `Pick` keeps only the listed keys, while `Omit` keeps everything except them.**

Both derive a new object type from `User`: `Pick` selects the named keys and `Omit` drops them, leaving the remaining properties unchanged.

- **B:** Neither utility changes the `?` modifier on the properties it carries over.
- **C:** Both build a new type; there is no copying or referencing at runtime.
- **D:** `Omit` accepts keys outside the type, and it certainly does not reject real ones.

</details>

### 35. Utility Types

`ts-cards-16-2`

What does `Partial<T>` produce, and what reverses it?

- **A.** It types every property as `T | undefined`, and `NonNullable<T>` restores the originals.
- **B.** It makes every property optional, and `Required<T>` makes every property required again.
- **C.** It makes every property `readonly`, and a built-in `Mutable<T>` reverses that.
- **D.** It makes every property nullable, and `Exclude<T, null>` reverses it for the whole type.

<details>
<summary>Reveal answer</summary>

**B. It makes every property optional, and `Required<T>` makes every property required again.**

`Partial<T>` adds the `?` modifier to each key and `Required<T>` strips it with `-?`; both are mapped types written over `keyof T`.

- **A:** `NonNullable` operates on a single type, not on the properties of an object type.
- **C:** `Readonly<T>` handles that modifier, and no `Mutable` utility ships with TypeScript.
- **D:** `Partial` never introduces `null`, and `Exclude` filters union members instead.

</details>

### 36. Utility Types

`ts-cards-16-3`

Which type does `Record<"read" | "write", boolean>` describe?

- **A.** `{ [key: string]: boolean }`, an index signature covering every string key.
- **B.** `{ read?: boolean; write?: boolean }`, with both properties optional.
- **C.** `{ read: boolean; write: boolean }`, with both properties required.
- **D.** `{ key: "read" | "write"; value: boolean }`, a single key-and-value pair.

<details>
<summary>Reveal answer</summary>

**C. `{ read: boolean; write: boolean }`, with both properties required.**

`Record<K, V>` maps each member of the key union `K` to the value type `V`, producing required named properties rather than an index signature.

- **A:** An index signature appears only when the key type is `string` itself, not a literal union.
- **B:** `Record` adds no `?` modifier, so both properties are required.
- **D:** `Record` builds one property per key, not a single entry object.

</details>

### 37. const Assertions

`ts-cards-17-1`

What does adding `as const` to `const routes = ["home", "about"]` change?

- **A.** It infers `readonly ["home", "about"]`, a readonly tuple of literal types.
- **B.** It infers `string[]` while additionally blocking reassignment of the binding.
- **C.** It infers a tuple whose element types remain the widened type `string`.
- **D.** It marks the array for constant folding so the compiler inlines it at each use.

<details>
<summary>Reveal answer</summary>

**A. It infers `readonly ["home", "about"]`, a readonly tuple of literal types.**

A const assertion keeps literal types instead of widening them, marks members `readonly`, and infers array literals as tuples rather than arrays.

- **B:** `const` already blocks reassignment, and the assertion prevents the widening to `string[]`.
- **C:** The literal element types are exactly what the assertion preserves.
- **D:** No optimization is implied; the emitted array literal is unchanged.

</details>

### 38. const Assertions

`ts-cards-17-2`

Does `as const` stop the object from being mutated while the program runs?

- **A.** Yes, because the compiler emits an `Object.freeze` call around the literal.
- **B.** Yes, because assignments to its members are removed during compilation.
- **C.** No, because it is a compile-time assertion that a cast or `any` can still bypass.
- **D.** No, but it does add a development-mode warning whenever a member is written.

<details>
<summary>Reveal answer</summary>

**C. No, because it is a compile-time assertion that a cast or `any` can still bypass.**

Const assertions exist only in the type system and are erased on emit, so runtime immutability needs `Object.freeze` or a structure that enforces it.

- **A:** Nothing is emitted; freezing has to be written explicitly if it is wanted.
- **B:** Assignments are never stripped, and a rejected write is a compile error, not a rewrite.
- **D:** There is no runtime instrumentation in either development or production output.

</details>

### 39. satisfies vs Assertions

`ts-cards-18-1`

What does `satisfies` do that a type assertion with `as` does not?

- **A.** It validates the value while the program runs and throws when the shape is wrong.
- **B.** It converts the value to the target type, supplying any properties that are missing.
- **C.** It suppresses the mismatch and records it for the build report instead.
- **D.** It checks the value against the type while keeping the value's own narrower inferred type.

<details>
<summary>Reveal answer</summary>

**D. It checks the value against the type while keeping the value's own narrower inferred type.**

`as` replaces the inferred type and can hide a mistake, while `satisfies` verifies the value against a type and leaves the literal's narrower inference in place.

- **A:** Both operators are erased on emit and perform no runtime work.
- **B:** Neither operator adds properties; the value is passed through exactly as written.
- **C:** A mismatch under `satisfies` is a hard error, never a deferred note.

</details>

### 40. satisfies vs Assertions

`ts-cards-18-2`

What does `JSON.parse(body) as User` guarantee about the parsed value?

- **A.** Nothing at runtime; it only instructs the compiler to treat the value as a `User`.
- **B.** That every required `User` property is present, verified at the moment of the cast.
- **C.** That missing properties are filled with `undefined` so the shape matches `User`.
- **D.** That the parse throws when the payload does not match the declared `User` shape.

<details>
<summary>Reveal answer</summary>

**A. Nothing at runtime; it only instructs the compiler to treat the value as a `User`.**

Type assertions are erased on compile, so asserting untrusted data just moves the failure to the first place a missing field is actually used.

- **B:** Assertions are not checks, so a missing property passes straight through.
- **C:** No properties are added; the parsed object is handed back unchanged.
- **D:** `JSON.parse` throws only on invalid syntax, never on an unexpected shape.

</details>

### 41. Typing API Responses

`ts-cards-19-1`

With the standard DOM library typings in TypeScript 5.x, what is the static type of `await response.json()`?

- **A.** `unknown`, so the result has to be narrowed before any property is read.
- **B.** `any`, so every property read on the result goes unchecked.
- **C.** `object`, so only members declared on `Object.prototype` are reachable.
- **D.** `Record<string, unknown>`, so string-keyed access is allowed but stays `unknown`.

<details>
<summary>Reveal answer</summary>

**B. `any`, so every property read on the result goes unchecked.**

The DOM typings declare `json(): Promise<any>`, which is why an unvalidated response silently accepts any property access.

- **A:** That is the safe design many wrappers adopt, but it is not what the DOM typings declare.
- **C:** The declared type is not `object`, and such a type would reject ordinary property reads.
- **D:** No such constraint is declared, and a JSON body may be an array or a primitive.

</details>

### 42. Typing API Responses

`ts-cards-19-2`

Which approach actually makes an HTTP response safe to use as a typed `User`?

- **A.** Annotating the fetch helper's return type as `Promise<User>` so callers see `User`.
- **B.** Asserting the parsed body with `as User` immediately after `JSON.parse`.
- **C.** Parsing into `unknown` and validating it with a schema or a type-predicate check.
- **D.** Declaring the response shape as an interface so the compiler verifies the payload.

<details>
<summary>Reveal answer</summary>

**C. Parsing into `unknown` and validating it with a schema or a type-predicate check.**

Only a runtime check can prove an external payload matches the type, so the body should enter as `unknown` and get its type from a validator that inspects it.

- **A:** The annotation is a claim about the payload, and nothing checks it at runtime.
- **B:** An assertion is erased on emit and proves nothing about the received data.
- **D:** The compiler checks source code, never the bytes that arrive over the network.

</details>

### 43. Typing API Responses

`ts-cards-19-3`

An `async` function's body returns a `User`. What is its return type, and what does awaiting the call give?

- **A.** `User`, and awaiting the call yields a `Promise<User>` that must be resolved again.
- **B.** `Promise<Promise<User>>`, and awaiting it unwraps one level to `Promise<User>`.
- **C.** `User | Promise<User>`, and awaiting selects whichever form the body produced.
- **D.** `Promise<User>`, and awaiting the call yields a `User`.

<details>
<summary>Reveal answer</summary>

**D. `Promise<User>`, and awaiting the call yields a `User`.**

An `async` function always returns a promise of the body's type, and `await` unwraps it; returning a promise from the body is flattened rather than nested.

- **A:** This inverts the two: the function returns the promise and `await` unwraps it.
- **B:** The compiler wraps the body's type once, and nested promises are flattened.
- **C:** An `async` function always returns a promise, so no such union arises.

</details>

### 44. React Props and Events

`ts-cards-20-1`

Which type should annotate the parameter of an `onChange` handler for a text `<input>` in React?

- **A.** `Event`, the base DOM event type shared by every listener.
- **B.** `React.ChangeEvent<HTMLInputElement>`, the synthetic event for that element.
- **C.** `React.FormEvent`, on the grounds that the input belongs to a form.
- **D.** `InputEvent<HTMLInputElement>`, the native event the browser dispatches.

<details>
<summary>Reveal answer</summary>

**B. `React.ChangeEvent<HTMLInputElement>`, the synthetic event for that element.**

React passes a synthetic event object, and supplying the element type is what makes `event.target.value` available as a `string`.

- **A:** It lacks the typed `target`, so `event.target.value` would not be checked.
- **C:** Form events cover submission; a change handler receives the change event instead.
- **D:** React hands the handler its own synthetic event, and this generic form does not exist.

</details>

### 45. React Props and Events

`ts-cards-20-2`

How do you type a `Button` that accepts every native `<button>` attribute plus a `variant` prop?

- **A.** `type Props = HTMLButtonElement & { variant: string }`
- **B.** `interface Props extends JSX.Element { variant: string }`
- **C.** `type Props = React.ComponentPropsWithoutRef<"button"> & { variant: string }`
- **D.** `type Props = React.ReactNode & { variant: string }`

<details>
<summary>Reveal answer</summary>

**C. `type Props = React.ComponentPropsWithoutRef<"button"> & { variant: string }`**

`ComponentPropsWithoutRef<"button">` is the prop type of the intrinsic element, so intersecting it adds the custom prop while keeping every native attribute.

- **A:** That is the DOM node type, not the React props accepted by the element.
- **B:** `JSX.Element` is the type of rendered output, so it declares no props at all.
- **D:** `ReactNode` describes renderable children rather than a component's props.

</details>

