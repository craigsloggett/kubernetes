# Prerequisites

## Raspberry Pis

This tutorial uses the [Raspberry Pi 4](https://www.raspberrypi.org/products/raspberry-pi-4-model-b/) for the compute infrastructure of the Kubernetes cluster. They can be purchased from [CanaKit](https://www.canakit.com/raspberry-pi-4-2gb.html) in Canada, or the [official website](https://www.raspberrypi.org/products/raspberry-pi-4-model-b/) can be used to find a local retailer.

## Running Commands in Parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. Labs in this tutorial may require running the same commands across multiple compute instances, in those cases consider using tmux and splitting a window into multiple panes with synchronize-panes enabled to speed up the provisioning process.

> Enable synchronize-panes by pressing `ctrl+b` followed by `shift+:`. Next type `set synchronize-panes on` at the prompt. To disable synchronization: `set synchronize-panes off`.

Next: [Installing the Client Tools](02-client-tools.md)
