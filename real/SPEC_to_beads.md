@docs/spec.md If you were to break this project down into sprints and beads, how
would you do it (timeline info does not need included and doesnt matter) - every
bead should be an atomic, commitable piece of work with tests (and if tests
don't make sense another form of validation that it was completed successfully),
every sprint should result in a demoable piece of software that can be run, tested,
and build ontop of previous work/sprints. Be exhaustive, be clear, be technical,
always focus on small atomic beads that compose up into a clear goal for the sprint.
Once you're done, provide this prompt to a subagent to review your work and suggest
improvements. When you're done reviewing the suggested improvements, create your
beads using `br` (beads_rust) - one bead per atomic task.