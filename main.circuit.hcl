# Facts give each host's distribution, which picks the Python checkov runs on.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = try(each.value.os, self.os_id) == self.os_id
      error_message = "Host ${each.key} is ${self.os_id}, not the ${try(each.value.os, "")} its os says."
    }
    precondition {
      condition     = local.requirements != ""
      error_message = "No requirements file at ${local.requirements_file}. This circuit ships one for each checkov_version it was tested with. For another version, make one and pass it as requirements_file."
    }
    precondition {
      condition     = can(regex("(?m)^checkov==${replace(var.checkov_version, ".", "\\.")}[ ;\\\\]", local.requirements))
      error_message = "${local.requirements_file} doesn't pin checkov==${var.checkov_version}."
    }
  }
}

locals {
  # A host object's os stands in for the facts of a host created in the
  # same plan, which can't be read until it exists.
  os = { for name, h in var.hosts : name => try(h.os, data.conn3x_host.facts[name].os_id) }

  # Fedora 45's python3 is 3.15, and checkov's pins hold pycares to 4.x,
  # which has no wheels for it. Fedora ships 3.12 alongside, the newest
  # Python checkov lists. Debian and Ubuntu split venv support out of python3.
  python       = { for name, o in local.os : name => o == "fedora" ? "python3.12" : "python3" }
  venv_support = { for name, o in local.os : name => contains(["debian", "ubuntu"], o) ? "python3-venv" : local.python[name] }

  requirements_file = coalesce(var.requirements_file, "${path.module}/requirements/checkov-${var.checkov_version}.txt")
  requirements      = fileexists(local.requirements_file) ? file(local.requirements_file) : ""

  home   = "/opt/checkov/${var.checkov_version}"
  venv   = "${local.home}/venv"
  locked = "${local.home}/requirements.txt"
}

circuit "checkov" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "python" {
    package {
      name = local.python[each.key]
    }
  }

  step "venv_support" {
    package {
      name = local.venv_support[each.key]
    }
  }

  # Every package checkov needs is pinned with its hashes, so pip refuses
  # anything PyPI serves that isn't the file that was locked.
  step "requirements" {
    file {
      path    = local.locked
      content = local.requirements
    }
  }

  # A venv of its own keeps checkov's pins away from the system's Python
  # packages. Wheels only, so nothing is built on the host and every file pip
  # installs is one whose hash is in the lock. The marker holds the lock's
  # hash, so a changed lock, or a venv left broken by a Python upgrade,
  # installs again from scratch.
  step "install" {
    command {
      command  = "rm -rf ${local.venv} && /usr/bin/${local.python[each.key]} -m venv ${local.venv} && ${local.venv}/bin/python -m pip install --quiet --disable-pip-version-check --no-input --require-hashes --no-deps --only-binary :all: -r ${local.locked} && ${local.venv}/bin/checkov --version >/dev/null && sha256sum < ${local.locked} > ${local.venv}/.conn3x-installed"
      unless   = "[ \"$(sha256sum < ${local.locked})\" = \"$(cat ${local.venv}/.conn3x-installed)\" ] && ${local.venv}/bin/checkov --version >/dev/null 2>&1"
      triggers = { requirements = conn3x_file.checkov__requirements[each.key].revision }
    }
  }

  step "link" {
    link {
      path   = "/usr/local/bin/checkov"
      target = "${local.venv}/bin/checkov"
    }
  }
}
