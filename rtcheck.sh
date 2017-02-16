#!/bin/bash

if [ -z $1 ]; then

	echo "usage: rtcheck cpu_number"
	exit 1

fi

RT_CPU=$1

info ()
{
	echo "$1"
}

success ()
{
	echo -e "\e[92m[OK]\e[0m $1"
}

warning ()
{
	echo -e "\e[93m[WARN]\e[0m $1"
}

error ()
{
	echo -e "\e[91m[ERR]\e[0m $1"
}

check_rt()
{
	PREEMPTION=`uname -v | grep "PREEMPT RT"`
	if [ -z $PREEMPTION ]; then
		error "PREEMPT RT not present or not enabled."
	else
		success "PREEMPT RT enabled"
	fi
	
	CG_MOUNTED=`mount | grep cgroup | wc -l`
	if [ $CG_MOUNTED -gt 0 ]; then
		warning "Mounted CGroups. They may cause unexpected delays."
	fi

}

check_cmdline()
{
	ISOLATED_CPU=`cat /proc/cmdline | sed -ne 's/.*isolcpus=//p' | sed 's/ .*//'`
	if [ -z $ISOLATED_CPU ]; then
		error "Missing isolcpus kernel command line."
		return
	fi

	OK=0
	for i in $(echo $ISOLATED_CPU | sed "s/,/ /g")
	do
		if [ $i == $RT_CPU ]; then
			success "CPU correctly isolated"
			OK=1
			break
		fi
	done

	if [ $OK == 0 ]; then
		error "CPU not in isolcpus kernel command line."
	fi
}

general_info()
{
	echo -n "Hostname: "
	hostname
	echo -n "Kernel release: "
	uname -r
	echo -n "Kernel version: "
	uname -v

	echo -n "Number of loaded kernel modules: "
	LSMOD_COUNT=`lsmod | wc -l`
	NR_KERN_MODULE=`expr $LSMOD_COUNT - 1`
	if [ $NR_KERN_MODULE -lt 0 ]; then
		NR_KERN_MODULE=0
		echo $NR_KERN_MODULE;
	else
		echo $NR_KERN_MODULE;
		warning "Kernel modules must be carefully analyzed."
	fi

	VM_STAT_INTERVAL=`cat /proc/sys/vm/stat_interval`
	info "VM Stat interval: $VM_STAT_INTERVAL"
	if [ $VM_STAT_INTERVAL -le 10 ]; then
		warning "VM Stat interval seems too low ($VM_STAT_INTERVAL)"
	fi


	if [ -e /proc/sys/kernel/watchdog ]; then
		if [ `cat /proc/sys/kernel/watchdog` -gt 0 ]; then
			error "Watchdog enabled"
		else
			success "Watchdog disabled"
		fi
	fi

	if [ -e /sys/bus/workqueue/devices/writeback/numa ]; then
		if [ `cat /sys/bus/workqueue/devices/writeback/numa` -gt 0 ]; then
			error  "NUMA workqueue writeback enabled"
		else
			warning "NUMA workqueue writeback enabled"
		fi 
	fi

	if [ -e /sys/bus/workqueue/devices/writeback/cpumask ]; then
		WRITEBACK_CPU=`cat /sys/bus/workqueue/devices/writeback/cpumask`
		if ((("0x$WRITEBACK_CPU" & $RT_CPU ))); then
			error "CPU is in the workqueue writeback cpumask"
		else
			success "CPU out of workqueue writeback cpumask"
		fi
	fi

}

check_core()
{
	CPUFREQ_DIR="/sys/devices/system/cpu/cpu$RT_CPU/cpufreq"
	if [ -e $CPUFREQ_DIR/scaling_governor ]; then
		GOVERNOR=`cat /sys/devices/system/cpu/cpu$RT_CPU/cpufreq/scaling_governor`
		if [ "$GOVERNOR" != "performance" ]; then
			error "CPU Governor is not in performance"
		else
			success "CPU Governor is in performance"
		fi
	else
		warning "No available info on scaling governor"
	fi

	if [ -e $CPUFREQ_DIR/scaling_max_freq ]; then
		MAX_FREQ=`cat $CPUFREQ_DIR/scaling_max_freq`
		CUR_FREQ=`cat $CPUFREQ_DIR/scaling_cur_freq`
		if [ $MAX_FREQ -ne $CUR_FREQ ]; then
			warning "CPU frequency is not the maximum available"
		else
			success "CPU frequency at max"
		fi
	else
		warning "No available info on scaling frequency"
	fi

	for irq in /proc/irq/*; do

		IRQ_NAME=`echo $irq | cut -d'/' -f4`

		if [ $IRQ_NAME == "default_smp_affinity" ]; then
			AFFINITY=`cat $irq`
			if ((("0x$AFFINITY" & $RT_CPU ))); then
				error "CPU is in the default IRQ affinity list"
			else
				success "CPU is not in the default IRQ affinity list"
			fi
			continue;
		fi
		AFFINITY=`cat $irq/smp_affinity`
		if ((("0x$AFFINITY" & $RT_CPU ))); then
			warning "CPU is in affinity list of IRQ $IRQ_NAME"
		else
			success "CPU out of affinity list of IRQ $IRQ_NAME"
		fi
	done

}

echo
info "== General system information =="
general_info

echo
info "== General Real-Time checks =="
check_rt

echo
info "== Command line options =="
check_cmdline

echo
info "== Core-specific setings  =="
check_core
