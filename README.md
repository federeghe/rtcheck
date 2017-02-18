rtcheck
=======

This script checks for the usual system and kernel configurations for PREEMPT_RT Linux system.


Usage
------
`rtcheck cpu_number`

* `cpu_number` argument represents the CPU in which you want to run your RT application.

If kernel configuration is not present under `/boot` directory or `/proc/config.gz`, please load
the relative module:

`modprobe configs`


Warning
-------
Please use the results of this tool with caution: correctly
configure a PREEMPT_RT system is a difficult task. It requires
to check the effects of every single step in the configuration.
A successful result of this tool **DOES NOT** mean that your Linux
system is correctly configured for real-time applications.
