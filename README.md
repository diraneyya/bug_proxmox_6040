# Proxmox Bug 6040 - Patch Documentation

This repository contains a functional demo, and a following discussion.

The intention is first to demonstrate, and only then to explain the context and the rationale for the [patch](https://lore.proxmox.com/pve-devel/mailman.80.1736016466.441.pve-devel@lists.proxmox.com/T/#u) I submitted, answering to bug 6040 which I reported [here](https://bugzilla.proxmox.com/show_bug.cgi?id=6040).

## Table of contents

- Demo instructions
- Discussion

## Demo

The purpose of the demo is to demonstrate how exclude patterns work when extracting a `tar` archive in Debian-12 Linux (i.e. the root operating system of the Proxmox distro).

### Instructions

1. Clone the repository. I prefer to clone all of my reposories to `$HOME/repos`, which I am assuming below:
  
   ```bash
   cd
   git clone https://github.com/diraneyya/bug_proxmox_6040.git tar_extraction_demo
   cd tar_extraction_demo
   ```
  
1. After cloning the repository, type in the following commands in your local *nix-like system:
  
   ```bash
   tar tf file1.tar
   tar tf file2.tar
   ```

   > [!TIP]
   > The `t` option stands for "Tree", which lists the file paths inside of the archive. The `f` option stands for "File", and allows the user to use a filename ending with `.tar` for finding the archive.
   
   > [!NOTE]
   > The two files, [file1.tar](./file1.tar) and [file2.tar](./file2.tar) contains the same files and directories. Yet, there is something different between the two, what is it?
   
1. Now is the time to spin up the demo using the [demo.sh](./demo.sh) script:
   
   ```bash
   cd ~/repos/tar_extraction_demo
   # run the script
   ./demo.sh
   ```

1. The script might take a bit of time to run, the first time you invoke it. It might also offer instructions on how to install missing utilities (such as `tree` or `tmux`) or exit if the `docker` command is not found on the local system. 
   
   > [!TIP]
   > Docker is used by the script to mimic the Debian-12 environment used by Proxmox when extracting archives using `(GNU tar) 1.34`.

   > [!NOTE]
   > Unlike `tree` and `tmux`, the script does not try to offer advice on how to install Docker.
   
1. After the demo is spun up, you will be able to see a horizontal pane at the top, for experimenting with different exclude patterns, and three vertical panes showing, in order:
   - The archive original contents. (left)
   - The extracted content when the supplied arguments are used to extract `file1.tar`. (middle)
   - The extracted content when the supplied arguments are used to extract `file2.tar`. (right)

   ![](./demo.png)

   > [!TIP]
   > Initially, the bottom middle and bottom right panes, are empty. This will change as you start running the extraction commands at the top pane. Note that with every extraction, the contents of the folders is wiped out, removing files from previous extractions. Hence, if the extraction command fails, then both directories become empty.

1. Now let us start by extracting both archives using no exclusion patterns what so ever:
   
   ```bash
   test_tar_extraction
   ```

   > [!TIP]
   > The `test_tar_extraction` helper will take the arguments you supply to it and channel them to `tar` for the extraction of both archives.

   > [!TIP]
   > Can you make sense of what you see? Are you able to see the full `tar` command being used? is the extraction successful?

1. Now let us try to supply an empty exclusion pattern, as follows:
   
   ```bash
   test_tar_extraction --exclude
   ```

   > [!TIP]
   > Can you make sense of what you see? Are you able to see the full `tar` command being used in this case? was the extraction successful?

1. Now, try the following exclude patterns, while taking the time to contemplate what you see, and what it means:
   
   ```bash
   test_tar_extraction --exclude *
   test_tar_extraction --exclude sample123
   test_tar_extraction --exclude ./sample123
   test_tar_extraction --exclude sample123/*
   test_tar_extraction --exclude ./sample123/*
   ```

   > [!TIP]
   > Note that there is a root `sample123` folder, which is intended to match the root `dev` folder in a root filesystem archive. There is also another, nested `sample123`, which needs to be extracted, along with its contents.

1. Taking into account what you learnt above, now you are able to supply the exclude patterns needed to exclude the root `sample123` folder in **both** archives:
   
   ```bash
   test_tar_extraction --exclude sample123/* --exclude ./sample123/*
   # smarter alternative, which expands to the same
   test_tar_extraction --exclude={,./}sample123/*
   ```

> Now you are ready to proceed to the discussion! Just remember to exit the demo using <kbd>Ctrl</kbd> + <kbd>B</kbd>, followed by <kbd>D</kbd>, then type the following in the terminal:
> ```bash
> cd ~/repos/tar_extraction_demo
> # run the cleaning script
> ./demo.sh clean
> ```

## Discussion

There are many root filesystems published on the internet for virtualization purposes. Some of these are intended for virtual machines, and some of them, are intended for containerization.

Some of these root-filesystem tarballs contains paths that start with a _dot slash_ (like [file1.tar](./file1.tar)), while others, contain paths that start immediately (just like like [file1.tar](./file1.tar) in this repository).

Some of these root-filesystem tarballs, on the other hand, do not contain a root `dev` directory, some contain a populated one, while others, contain a non-populated one.

This matters because, tarballs that contain a populated root `dev` directory are not compatible with LXC containers, since an LXC container gets its root `dev` folder populated during its creation.

Hence, when the tarball contains a populated root `dev` directory, even though the rest of the root filesystem contents can be used as the basis of an LXC container, the container creation fails.

### Current Code

This [line](https://github.com/proxmox/pve-container/blob/85a1397d7254b0d9f042c0558578f4d5488e5446/src/PVE/LXC/Create.pm#L78) excludes a root `dev` directory from being extracted to the container's root filesystem during LXC container creation (from `pve-container.git`/`src/PVE/LXC/Create.pm`):
```perl
    push @$cmd, '--exclude' , './dev/*';
```

The only issue here, is that the code assumes that in this case, the root filesystem tarball would have paths starting with a _dot slash_ (similar to [file1.tar](./file1.tar)), rather than starting with themselves (similar to like [file2.tar](./file1.tar)).

### Inquiry

Below is a table showing different root filesystem images found on the internet, and whether they present the isse of a _populated root `dev`folder_, along with the type of paths inside of the archive:

To look for these images, I searched for "cloud images", which often included different formats for different virtualization technologies. As long as I was able to find a root-filesystem tarball files published, I considered the idea and the attempt to use these tarballs to create containers valid.

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

As virtualization shifts from VMs to containers, many Proxmox users are already [on a mission](https://forum.proxmox.com/threads/docker-to-pve-lxc-conversion-steps-tool.143193/#post-735844) to run their VM workloads as Linux containers, instead.

To create an LXC container, we must obtain an archive that captures the contents of the root filesystem. These root filesystem archives have existed prior to containerization. An example of legacy root filesystem images are `squashfs` files found in _live systems_ (i.e. systems booted from read-only media).

In the same way, projects distribute (along with their VM images), root filesystem tarballs that reflect everything in the filesystem of a working VM. These, despite not being intended for containerization, can be leveraged easily (just by excluding [root system folders](https://discuss.linuxcontainers.org/t/simple-script-to-convert-any-gnu-linux-machine-into-a-proxmox-lxc-container/10339)).

Namely, it would be a pity to have to repackage these archives, to leverage them as container templates.

Finally, there are more modernly distributed root filesystems, which are either created with containerization in mind (similar to those distributed by Archlinux), or as part of another containerization technology (e.g. Docker, using [docker2lxc](https://github.com/diraneyya/docker2lxc)).

#### Conclusion 

The root filesystem archives found online today fall into one of two categories:

1. Ones that are remnant from virtual machines.
1. Ones that are distributed with containerization in mind.

The legacy archives tend to:
- contain fully populated root system folders, including a fully-populated root `dev`folder
- contain paths that start immediately (with a _dot slash_ `./` at the beginning)

The modern archives, on the other hand, tend to:
- contain empty root system folders, including an empty root `dev` folder
- contain paths that start wit a _dot slash_ `./`

> Hence, it is my belief that for the exclusion of the root `dev` folder (to prevent container-creation failure), which have existed in the codebase for almost 8 years now, **it makes more sense to use an exclusion pattern that does not start with a _dot slash_ `./`, which is what this patch does**

#### Patch 

https://lore.proxmox.com/pve-devel/mailman.80.1736016466.441.pve-devel@lists.proxmox.com/T/#u