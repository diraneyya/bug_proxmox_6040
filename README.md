# Proxmox Bug 6040 - Patch Documentation

_This repository contains a functional demo, and a following discussion._

The intention is to demonstrate, and then explain the context for [bug report 6040](https://bugzilla.proxmox.com/show_bug.cgi?id=6040) and the suggested [patch](https://lore.proxmox.com/pve-devel/mailman.80.1736016466.441.pve-devel@lists.proxmox.com/T/#u).

## Table of contents

- Instructions for Interactive Demo
- Discussion and Rational for Patch

## Interactive Demo

The purpose of the demo is to demonstrate how exclude patterns work under `tar`.

### Instructions

1.  Clone the repository. I prefer to clone all of my repositories to `$HOME/repos`, which I am assuming below:

    ```bash
    cd ~
    git clone https://github.com/diraneyya/bug_proxmox_6040.git tar_extraction_demo
    cd tar_extraction_demo
    ```
  
2.  After cloning the repository, type in the following commands: 
    ```bash
    cd ~/repos/tar_extraction_demo
    tar tf file1.tar
    tar tf file2.tar
    ```
  >  [!TIP]
  > The `t` option stands for "Tree", which lists the file paths inside of the archive. The `f` option stands for "File", and allows the user to select the tar archive using its filename.
  
  > [!NOTE]
  > The two files, [file1.tar](./file1.tar) and [file2.tar](./file2.tar) contain the same set of files and directories. Yet, they are different in an important way. Run the two commands above to figure out how.
  
3.  Now is the time to spin up the demo using the [demo.sh](./demo.sh) script:
   
    ```bash
    cd ~/repos/tar_extraction_demo
    # run the script
    ./demo.sh
    ```

4.  The script might take a bit of time to run, the first time you invoke it. It might also offer instructions on how to install missing utilities (such as `tree` or `tmux`) or exit if the `docker` command is not found on the local system. 
   
  > [!TIP]
  > Docker is used by the script to mimic the Debian-12 environment used by Proxmox when extracting archives.

  > [!NOTE]
  > Unlike `tree` and `tmux`, the script does not try to offer advice on how to install Docker.
   
5.  After the demo is spun up, you will be able to see a horizontal pane at the top, for experimenting with different exclude patterns, and three vertical panes at the bottom. These are for:
    - The archive's original contents in the [contents](./contents) folder. (bottom left)
    - The results of extracting [file1.tar](./file1.tar) to the [extracted1](./extracted1) folder. (bottom middle)
    - The results of extracting [file2.tar](./file2.tar) to the [extracted2](./extracted2) folder. (bottom right)

    ![](./demo.png)

  > [!TIP]
  > Initially, the bottom middle and bottom right panes, are empty. This will change as you start running the extraction commands at the top pane. Note that with every extraction, the contents of the folders are wiped out to simulate a fresh start. Hence, if the extraction command fails, then both directories will remain empty.

6.  Now let us start by extracting both archives using no exclusion patterns at all:
   
    ```bash
    test_tar_extraction
    ```

  > [!TIP]
  > The `test_tar_extraction` helper will take the arguments you supply to it and channel them to `tar` for the extraction of both archives (i.e. [file1.tar](./file1.tar) and [file2.tar](./file2.tar)).

  > [!WARNING]
  > Can you make sense of what you see? Are you able to see the full `tar` command being used? was the extraction successful?

7.  Now let us try to supply an empty exclusion pattern, as follows:
   
    ```bash
    test_tar_extraction --exclude
    ```

  > [!WARNING]
  > Can you make sense of what you see? Are you able to see the full `tar` command being used? was the extraction successful in this case?

8.  Now, try some exclude patterns:
   
   ```bash
   test_tar_extraction --exclude *
   test_tar_extraction --exclude sample123
   test_tar_extraction --exclude ./sample123
   test_tar_extraction --exclude sample123/*
   test_tar_extraction --exclude ./sample123/*
   ```

  > [!NOTE]
  > As you may have already figured out, the root `sample123` folder is intended to model the root `dev` folder (in a root filesystem archive). There are two folders named `sample123`, one of which needs to be extracted (the nested one), while the other's contents need to be excluded (the one at the root of the archive).

9. Taking into account what you learnt above, now you are able to supply the exclude patterns needed to exclude the root `sample123` folder in **both** archives:
   
   ```bash
   test_tar_extraction --exclude sample123/* --exclude ./sample123/*
   # smarter alternative, which expands to the same
   test_tar_extraction --exclude={,./}sample123/*
   ```

### Cleaning Up

Before moving to the discussion. Exit the demo using <kbd>Ctrl</kbd>+<kbd>B</kbd>, followed by pressing <kbd>D</kbd>. After that, clean the environment using the following command:
```bash
cd ~/repos/tar_extraction_demo
# run the cleaning script
./demo.sh clean
```

## Discussion

There are many root filesystems published on the internet for virtualization purposes. Some of these are intended for virtual machines, and some of them, are intended for containers.

Some of these root-filesystem tarballs contains paths that start with a _dot slash_ (like [file1.tar](./file1.tar)), while others, contain paths that start immediately (like [file2.tar](./file1.tar)).

Additonally, some of these root-filesystem tarballs contain populated system root folder (e.g. a populated `dev`), while others, omit these directories or contain unpopulated one.

This matters because, tarballs that contain a populated root `dev` directory are not compatible with LXC containers, since an LXC container gets its root `dev` folder populated during its creation.

Hence, when the tarball contains a populated root `dev` directory, even though the rest of the root filesystem contents can be used as the basis of an LXC container, the container creation fails.

### Current Code

This [line](https://github.com/proxmox/pve-container/blob/85a1397d7254b0d9f042c0558578f4d5488e5446/src/PVE/LXC/Create.pm#L78) excludes a root `dev` directory's contents from being extracted to the container's root filesystem during LXC container creation (from `pve-container.git`/`src/PVE/LXC/Create.pm`):
```perl
    push @$cmd, '--exclude' , './dev/*';
```

<mark>The only issue here, is that the current code assumes that the tarball has paths starting with a _dot slash_ (similar to [file1.tar](./file1.tar)), rather than starting directly (similar to [file2.tar](./file2.tar)).</mark>

### Inquiry

Below is a table showing different root filesystem images found on the internet, and the challenges they present when it comes to LXC container creation in Proxmox.

To look for these images, I searched the web for "cloud images", which often included different formats for different virtualization technologies. As long as I was able to find something that contains a root-filesystem archive of any kind, I considered the idea of attempting to use these archives to create LXC containers a valid one.

| Project    | Archive Path Prefix | Root `dev` Folder? | Before Patch | After Patch |
|------------|---------------------|--------------------|:------------:|:-----------:|
| Ubuntu[^1] | None | <mark>Populated</mark> | :x:                | :white_check_mark: |
| Alpine[^2] | `./` | Empty                  | :white_check_mark: | :white_check_mark: |
| Linux Containers[^3] | `./` | Empty | :white_check_mark: | :white_check_mark: |
| docker2lxc[^4] | `./` | Limited | :white_check_mark: | :white_check_mark: |
| sqfs2tar[^5] | None | <mark>Populated</mark> | :x: | :white_check_mark: |

[^1]: https://cloud-images.ubuntu.com/ (Look files ending with `-root.tar.xz`)
[^2]: https://alpinelinux.org/downloads/ (Look for _Mini Root Filesystems_)
[^3]: https://images.linuxcontainers.org/ (Look files named `rootfs.tar.xz`)
[^4]: Using [`docker2lxc`](https://github.com/diraneyya/docker2lxc) it was possible to convert this 10GB [universal:2](https://hub.docker.com/r/microsoft/devcontainers-universal) Microsoft Docker container to an LXC template, which worked.
[^5]: https://cdimage.debian.org/debian-cd/current-live/amd64. Using a live system ISO, the `sqfs2tar` utility was used to convert the `squashfs` filesystwm image to `tar`, which was then gzipped to create an LXC template.

> [!WARNING]
> This table is a work in progress.

### Rationale for the Patch

> [!TIP]
> This section is edited by ChatGPT.

As virtualization evolves from VMs to containers, Proxmox users increasingly seek to adapt existing VM workloads for Linux containers. A critical step in this process involves obtaining a root filesystem archive that encapsulates the operating system's essential contents. These archives, however, vary significantly depending on their origins:

1.  **Legacy Archives:** Derived from VM-oriented systems or live system images (e.g., squashfs archives).

    - Tend to include fully populated root folders (e.g. `/dev`).
    - Often omit a leading `./` prefix in file paths within the archive.

2.  **Modern Archives:** Designed for containerization or specific containerization technologies (e.g., Docker).

    - Typically contain minimal or empty root folders, including `/dev`.
    - Consistently include a `./` prefix for paths inside the archive.

The disparity in archive structure and paths creates challenges in LXC container creation, particularly with populated `/dev` directories. LXC containers manage their own `/dev`, and a populated `/dev` in the archive leads to creation failure.

### The Current Situation

The existing Proxmox codebase addresses this by excluding the `/dev` directory during archive extraction. However, the current exclusion pattern (--exclude `./dev/*`) assumes that all archive paths begin with `./`. While this works for modern archives, it fails for legacy archives lacking the `./` prefix. Consequently, users attempting to repurpose such archives must manually repackage them —a labor-intensive and unnecessary process.

### The Proposed Modification

The proposition is either to change the exclusion pattern to `dev/*`, to accommodate the legacy archives in which this failure is more likely to occur, or, alternatively, to accommodate both archive types. By using a more general exclusion pattern (`--exclude={,./}dev/*`), Proxmox can seamlessly handle archives with or without the `./` prefix in their paths. This approach eliminates the need for repackaging and ensures compatibility with a broader range of root filesystem archives.

### The Patch

https://lore.proxmox.com/pve-devel/mailman.80.1736016466.441.pve-devel@lists.proxmox.com/T/#u
