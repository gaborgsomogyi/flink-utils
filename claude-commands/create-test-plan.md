A skill for creating a structured test plan for a given Java class, designed for production-quality coverage.

## Guiding principle

Every decision in this skill must be grounded in facts observed directly from the code. Never assume behavior, infer intent, or extrapolate beyond what is explicitly present in the source. If something is unclear or ambiguous, ask the user. Assumptions are forbidden.

## Input

The class name is provided as: $ARGUMENTS

If $ARGUMENTS is empty, ask the user for the class name before proceeding. Do not continue until it is provided.

## Step 1 — Resolve the class

Search the codebase for Java files matching the class name. If multiple matches are found, list them with their full paths and ask the user to pick one. Do not guess.

## Step 2 — Analyze the class

Read the class file in full. For every method (public and package-private):
- Name, visibility, parameter names and types, return type
- Checked and unchecked exceptions declared or thrown
- Internal branches: conditionals, loops, early returns, null checks, error paths
- Side effects: state mutations, I/O, calls to external dependencies

Identify all external dependencies the class interacts with (databases, network clients, file systems, clocks, queues, etc.). Do not design mocks yet — just list them.

## Step 3 — Design the test plan

For each method, enumerate test cases by varying input categories:
- Valid representative inputs
- Boundary values (empty collections, zero, max values, etc.)
- Invalid inputs (null, negative, out-of-range, malformed)
- Each distinct internal branch or error path

For each test case:
- Write a descriptive name following the pattern `methodName_condition_expectedOutcome` — omit the words "given" and "then" from the name, the structure carries their meaning implicitly. The condition part must describe the scenario at a conceptual level, never enumerate individual parameter names. The outcome part must state the primary outcome, never list every assertion. A good name reads like a sentence a developer would say out loud. Target under 80 characters.
- Draft the structure as given / when / then, naming the inputs, the action, and the expected output or exception.
- Identify which external dependencies this case needs to control.

Group structurally identical cases (same method, same structure, varying data only) into parameterized tests using `@ParameterizedTest` + `@MethodSource`.

Any test case with no assertion is forbidden. If a case genuinely cannot assert anything, flag it explicitly and ask the user for explicit consent before including it.

As a by-product of this step, produce a consolidated list of mock requirements: for each external dependency, what behavior each test case needs from it.

## Step 4 — Resolve mocks

For each mock requirement derived in Step 3, search the test source tree for an existing mock, fake, stub, or test double that satisfies it. Cast a wide net: look for classes named `*Mock*`, `*Fake*`, `*Stub*`, `*TestDouble*`, `*Testing*`, `*Builder*` in test directories, and for inner classes inside existing test classes.

For each requirement:
- If a match is found: reference it by class name and file path in the plan.
- If no match is found: plan a new mock and describe what behavior it must provide.

## Step 5 — Gap analysis

Search for existing test files that cover this class (e.g., `ClassNameTest.java`, `ClassNameITCase.java`, or similar). Do not let existing tests influence the design produced in Steps 2–4.

Compare the planned test cases against the existing ones:
- Which planned cases are already covered? For each, state the existing location as `ClassName.methodName`.
- Which are missing? For each missing case, state where it should be added as `ClassName.methodName` where `ClassName` is the target test class (existing or to be created) and `methodName` is the planned test method name. Never omit the class name even when the method does not exist yet.

Every row in the gap table must show the planned test case in the Case column as `TargetTestClassName.plannedMethodName` — never as a bare method name.

Produce a prioritized proposal for filling the gaps, ordering by risk and importance.

## Step 6 — Output

Print the complete test plan:
- One section per method
- Each test case with its name, given/when/then sketch, and mock references
- New mocks that need to be created, with their required behavior

If existing tests were found, follow the plan immediately with the gap analysis. Every row in the gap table must include the location in `ClassName.methodName` format — both for existing coverage and for missing cases.

If no existing tests exist, state that explicitly, name the class that should be created, and present the full plan as the baseline to implement from.

## Constraints

- Java only. Test framework: JUnit 5. Mocking: Mockito. Assertions: AssertJ.
- Always derive mock requirements from the design before searching — never assume mocks upfront.
- Reuse existing mocks first, create new ones only when nothing suitable exists.
- No test without an assertion unless the user explicitly consents.
- Multiple assertions in one test are acceptable when they all verify facets of the same behavior — the framework reports which assertion failed. Only split into separate tests when the behaviors are genuinely independent.
- No comments explaining what code does — test names and structure carry that responsibility.
- Test observable behavior only: outputs, side effects, and exceptions produced by a method given specific inputs. Structural properties enforced by the compiler — inheritance, interface implementation, class hierarchy — must not be planned as test cases.
- Parameterized tests whenever two or more cases share the same method structure with varying data. Apply this as a mandatory final pass after all cases for a method are enumerated: sort cases by assertion structure — same setup shape, same assertion shape — and merge any group of two or more into a single `@ParameterizedTest`. Edge-case inputs (null, empty, whitespace, boundary values) are rows, not separate `@Test` methods, when the assertion shape is identical. Never write a standalone `@Test` for a case whose test body would be structurally identical to another case for the same method.
- When in doubt about scope, edge cases, or design decisions, ask the user. It is the developer's responsibility to make decisions.
- Never narrate format decisions, explain why the output looks a certain way, or comment on what changed between invocations. Always produce the full output directly.
- Methods that exist solely to produce human-readable output for logging or debugging — `toString()`, `toLogString()`, `toDebugString()`, and equivalents — must not be tested. Their format is not a functional contract: it can change freely without affecting correctness, and tests against it only add fragile coupling to an arbitrary string layout.
- No-logic factory methods whose output is fully determined by hardcoded constants — single return statement, no parameters, no computation — must not be tested. The compiler enforces that the constant is a valid value. More critically: Claude authors both the implementation and the test in the same session, so a wrong constant in the factory body would be mirrored by the same wrong constant in the test assertion; the test cannot catch the only failure mode it nominally guards against. Factory methods that accept parameters may still warrant edge-case tests, but only for real logic they exercise — null-handling in the constructor, defensive copying, branching — not for the trivial delegation itself.
