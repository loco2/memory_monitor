# `memory_monitor`

This program is used to run a command with a memory limit.

If the command exceeds the memory limit, it will receive a `SIGTERM` to
exit gracefully. If it fails to exit gracefully within a timeout, it
will receive a `SIGKILL` to exit ungracefully.

The memory measurement used is [*resident set
size*](https://en.wikichip.org/wiki/resident_set_size).

## Example


```
$ bin/memory_monitor --limit 20 --interval 0.1 --timeout 0.1 ruby -e 'trap("TERM", "IGNORE"); a=[]; loop { a << "foo" * 500000; puts "hi"; sleep 0.01 }'
hi
hi
hi
hi
hi
hi
hi
[memory_monitor] process memory 22.0MB exceeded limit 20MB, sending SIGTERM
hi
hi
hi
hi
hi
hi
hi
hi
hi
[memory_monitor] process failed to stop after 0.1s, sending SIGKILL
```

## Intended use

We are using this to monitor our Docker container processes to ensure
they get restarted after a memory leak occurs. Within the container, we
simply want the program to exit when its memory usage is too high. The
container orchestration system will then notice that the container has
died, and start a new one.

## Treatment of subprocesses

If the command spawns any subprocesses, they will also be checked.  We
don't check the total memory usage of the process and its subprocesses,
we check each one individually. If either the main process or any of its
subprocesses exceeds the limit, the main process gets killed.
(Signalling individual subprocesses while keeping the main process alive
would be more complex and is not worth it.)

## Bugs/features

* Memory usage is measured by shelling out to the `ps` command; the
  current implementation may be incompatible with some systems.
* Tested with Ruby 2.3, but may work on prior versions too.
