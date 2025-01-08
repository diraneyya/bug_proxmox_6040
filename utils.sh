function command_check {
    COMMAND_CHECK=$1
    COMMAND_REPO=$2
    if ! command -v sudo &>/dev/null; then NO_SUDO=1; fi
    if ! command -v $COMMAND_CHECK &>/dev/null; then
        printf >&2 "\e[1mPlease install the '$COMMAND_CHECK' command using:\e[0m\n"
        TEMPLATE="> \e[4;2m%s\e[0m %s\n"
        if command -v brew &>/dev/null; then 
            NO_SUDO=
            INSTALLATION_RECIPE="brew install $COMMAND_CHECK"
        elif command -v apk &>/dev/null; then 
            if [ -z "$NO_SUDO" ]; then
                INSTALLATION_RECIPE="sudo apk add $COMMAND_CHECK"; else
                INSTALLATION_RECIPE="apk add $COMMAND_CHECK"; fi
        elif command -v yum &>/dev/null; then 
            if [ -z "$NO_SUDO" ]; then
                INSTALLATION_RECIPE="sudo yum install -y $COMMAND_CHECK"; else
                INSTALLATION_RECIPE="yum install -y $COMMAND_CHECK"; fi
        elif command -v apt &>/dev/null; then 
            if [ -z "$NO_SUDO" ]; then
                INSTALLATION_RECIPE="sudo apt update && sudo apt install -y $COMMAND_CHECK"; else
                INSTALLATION_RECIPE="apt update && apt install -y $COMMAND_CHECK"; fi
        elif command -v zypper &>/dev/null; then
            if [ -z "$NO_SUDO" ]; then
                INSTALLATION_RECIPE="sudo zypper install -y $COMMAND_CHECK"; else
                INSTALLATION_RECIPE="zypper install -y $COMMAND_CHECK"; fi
        elif command -v pacman &>/dev/null; then
            if [ -z "$NO_SUDO" ]; then
                INSTALLATION_RECIPE="sudo pacman -Sy $COMMAND_CHECK"; else
                INSTALLATION_RECIPE="pacman -Sy $COMMAND_CHECK"; fi
        elif command -v dnf &>/dev/null; then
            if [ -z "$NO_SUDO" ]; then
                INSTALLATION_RECIPE="sudo dnf install $COMMAND_CHECK"; else
                INSTALLATION_RECIPE="dnf install $COMMAND_CHECK"; fi
        elif command -v snap &>/dev/null; then
            if [ -z "$NO_SUDO" ]; then
                INSTALLATION_RECIPE="sudo snap install $COMMAND_CHECK"; else
                INSTALLATION_RECIPE="snap install $COMMAND_CHECK"; fi
        else 
            NO_SUDO=
            INSTALLATION_RECIPE="$COMMAND_REPO"
        fi

        printf >&2 "$TEMPLATE" "$INSTALLATION_RECIPE" "${NO_SUDO:+(no sudo)}"
        exit 1
    fi
}