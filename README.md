# Eject LaCie 

This script is intended for specific use cases when a LaCie drive may fail to unmount due to a plausibly running process.

## Common Causes

It's a good idea to examine file descriptors in running applications, background I/O operations, or system daemons like `mds` (Spotlight indexing) or `backupd` (Time Machine). 

### Kernel-Level Locks

Kernel-level locks can prevent unmounting when processes have open inodes, when a shell has its current working directory (cwd) set to a path within the mount point, or when system services are writing to `.Spotlight-V100`, `.fseventsd`, or `.Trashes` directories.

### File System Issues

File system issues include journal corruption, unresolved dirty bits in the volume bitmap, bad blocks in the partition table, or filesystem inconsistencies detected by `fsck`. The volume manager may hold references if there are active file mappings (`mmap`), pending write buffers in the page cache, or if the filesystem is part of a RAID or `CoreStorage/APFS` volume group.

<img width="1571" height="980" alt="output (25)" src="https://github.com/user-attachments/assets/2e3525e5-a851-40cf-be28-0a030d920f40" />

<br>_The chart displays how long it took to eject or unmount the LaCie drive across several attempts. The `X-axis`, labeled “Unmount Attempt,” lists each attempt in order from the first to the fifth, while the `Y-axis`, labeled “Time (seconds),” shows how long each attempt took. The lime-green line represents those durations, and the shaded area beneath it visually emphasizes the trend, illustrating how eject times changed over successive attempts._</br>

### Software Conflicts

Software conflicts arise when `launchd` services, `cfprefsd`, or applications like Dropbox maintain file watches using `FSEvents` or `kqueue` on the mounted volume.

![fstab-mount-failure-diagram](https://github.com/user-attachments/assets/97a52cc6-eebd-4c6c-8957-2d1d8391bbf6)<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 1400">

### Hardware Issues

Hardware issues include bus enumeration problems on the `USB/Thunderbolt/FireWire` subsystem, incomplete `SCSI/ATA` command sequences, or the device node (`/dev/diskN`) being in an inconsistent state.

## Usage

Make sure you make the script executable:

```bash
# make script executable
chmod +x eject_lacie.sh

# auto-detect LaCie volume, kill blockers, force if needed, pause Spotlight:

sudo ./eject_lacie.sh -k -f -s

# or specify by name/path:

sudo ./eject_lacie.sh -v "LaCie" -k -f -s
sudo ./eject_lacie.sh -v /Volumes/LaCie -k -f -s
```
Enjoy. Contribs are welcome. 

## Author 

Michael Mendy (c) 2025. GPL. 
