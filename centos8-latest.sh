#!/bin/sh
set -e

echo_docker_as_nonroot() {
	if command_exists docker && [ -e /var/run/docker.sock ]; then
		(
			set -x
			$sh_c 'docker version'
		) || true
	fi
	your_user=your-user
	[ "$user" != 'root' ] && your_user="$user"
	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-EOF", spaces are kept in the output
	cat <<-EOF

	If you would like to use Docker as a non-root user, you should now consider
	adding your user to the "docker" group with something like:

	  sudo usermod -aG docker $your_user

	Remember that you will have to log out and back in for this to take effect!

	WARNING: Adding a user to the "docker" group will grant the ability to run
	         containers which can be used to obtain root privileges on the
	         docker host.
	         Refer to https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface
	         for more information.

	EOF
}

do_install() {

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
			cat >&2 <<-'EOF'
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
			exit 1
		fi
	fi

	yum_repo="https://download.docker.com/linux/centos/docker-ce.repo"

	pkg_manager="dnf"
	config_manager="dnf config-manager"
	enable_channel_flag="--set-enabled"
	pre_reqs="dnf-plugins-core iscsi-initiator-utils"

	(
		set -x

		$sh_c "$pkg_manager install -y -q $pre_reqs"
		$sh_c "$config_manager --add-repo=$yum_repo"

		$sh_c "$pkg_manager list docker-ce"
		$sh_c "$pkg_manager install docker-ce --nobest -y"
		$sh_c 'systemctl enable --now docker'
		$sh_c 'systemctl enable --now iscsid'

	)
	echo_docker_as_nonroot

			

	# intentionally mixed spaces and tabs here -- tabs are stripped by "<<-'EOF'", spaces are kept in the output
	cat >&2 <<-'EOF'

	Either your platform is not easily detectable or is not supported by this
	installer script.
	Please visit the following URL for more detailed installation instructions:

	https://docs.docker.com/engine/installation/

	EOF
	exit 1
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install
