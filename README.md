Requires:  
    linux os  
    qemu  
    netcat (likely installed)  
Usage:  
vthena create [opts] image.iso  
    creates a master vm, and starts it. install desired programs and dependencies then exit  
    This vm will be the default for most commands, named _master  
vthena clone [opts] base cloneName  
    creates a copy of base, default being _master  
    allows you to do modifications and test on those  
vthena start [opts] vmName  
    you may want to dev experiments in the vm to avoid dependency issues.  
    you can also run benchmarks directly from here but that misses the point  
vthena run [opts] vmName(all) experimentName  
    desired experiment is called on boot, then is shutdown after completion.  
    stdout/err is sent to experimentName.log in the experiments folder  
    keyword all runs experiment on all vms  
vthena set [opts] vmName  
    overrides _master vm used when one of your changes becomes a standard.  
vthena list  
    lists all created vms  
vthena clean  
    cleans all created vms besides master  
Example workflow: testing zfs configs  
    vthena create image.iso # creates _master  
    vthena clone zfs1MRecord # create branch  
    vthena start zfs1MRecord # add changes  
    ... # create more branches  
    vthena run all benchmark.sh # run tests  
    vthena set zfs1MRecord # sets vm as _master  
    vthena clean # removes old vm set  
    vthena clone zfsLZ4 # this clones zfs1MRecord not the original vm  
    vthena clone zfsLZ4 zfsLZ4NoCache # can branch from non-main, might be confusing tho, no branch management  
    # Happy testing!  
