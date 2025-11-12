# Eject LaCie 

<img width="1344" height="768" alt="I’m Under This Much Pressure (4)" src="https://github.com/user-attachments/assets/ab2212d5-4d46-4eed-9e13-318df8e8f579" />

This script is intended for specific use cases when a LaCie drive may fail to unmount due to a plausibly running process.

## Common Causes

It's a good idea to examine file descriptors in running applications, background I/O operations, or system daemons like `mds` (Spotlight indexing) or `backupd` (Time Machine). 

### Kernel-Level Locks

Kernel-level locks can prevent unmounting when processes have open inodes, when a shell has its current working directory (cwd) set to a path within the mount point, or when system services are writing to `.Spotlight-V100`, `.fseventsd`, or `.Trashes` directories.

<img width="1769" height="980" alt="output (26)" src="https://github.com/user-attachments/assets/5dd75628-6f9c-4179-b493-e095526ee1d1" />

<br> _This chart illustrates the time it took to eject the LaCie drive across six attempts, along with the likely cause of delay for each one. The x-axis lists each unmount attempt in order from the first through the sixth, while the y-axis measures the eject time in seconds._ </br> 

### File System Issues

File system issues include journal corruption, unresolved dirty bits in the volume bitmap, bad blocks in the partition table, or filesystem inconsistencies detected by `fsck`. The volume manager may hold references if there are active file mappings (`mmap`), pending write buffers in the page cache, or if the filesystem is part of a RAID or `CoreStorage/APFS` volume group.

<img width="1571" height="980" alt="output (25)" src="https://github.com/user-attachments/assets/2e3525e5-a851-40cf-be28-0a030d920f40" />

<br>_The chart displays how long it took to eject or unmount the LaCie drive across several attempts. The `X-axis`, labeled “Unmount Attempt,” lists each attempt in order from the first to the fifth, while the `Y-axis`, labeled “Time (seconds),” shows how long each attempt took. The lime-green line represents those durations, and the shaded area beneath it visually emphasizes the trend, illustrating how eject times changed over successive attempts._</br>

### Software Conflicts

Software conflicts arise when `launchd` services, `cfprefsd`, or applications like Dropbox maintain file watches using `FSEvents` or `kqueue` on the mounted volume.

<img width="1570" height="980" alt="output (27)" src="https://github.com/user-attachments/assets/d1734621-6607-4c1e-a5e7-c66a970fdd32" />

<br> _This chart shows the severity of software conflicts across five different instances, with each conflict labeled along the `X-axis` and its severity rated on a 1–5 scale along the `Y-axis`. The lavender line illustrates how the severity levels rise and fall between conflicts, while the filled lavender area underneath emphasizes the overall trend visually. In this example, Conflict 4 appears to be the most severe, Conflict 3 the least severe, and the remaining conflicts fall in the middle, giving you a clear visual snapshot of how impactful each issue was over time._ </br>

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
