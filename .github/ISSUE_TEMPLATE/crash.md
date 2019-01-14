---
name: Crash report
about: Report GameHub crashing under some circumstances
---

<!--
Before creating the issue, please make sure that...

* You are using the latest version of GameHub (active development happens in the dev branch).
* Your version of GameHub is compiled with optimization turned off (see here: https://github.com/tkashkin/GameHub/issues/162 for more info)
* There isn't already an open issue for your problem.

If you have multiple unrelated problems, create separate issues rather than combining them into one.

Note that leaving sections blank or being vague will make it difficult to understand and fix the problem.
-->

###### Steps to reproduce



###### Version and environment

<!-- Paste output of `com.github.tkashkin.gamehub -v` below: -->
```
PASTE VERSION INFO HERE
```

###### GDB log

<!--
To get the GDB log, follow these steps:

1. Close GameHub if it's running.
2. Run this in your terminal: `com.github.tkashkin.gamehub --gdb`
3. Once the app has crashed (become unresponsive), type "bt full" (and press enter) to get a backtrace.
4. Type "q" to quit the debugger (or "c" to continue until the app quits)
5. Copy the log and paste below
-->

<details>
<summary>GDB log</summary>

```
PASTE LOG HERE
```

</details>
