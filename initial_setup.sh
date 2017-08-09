#!/usr/bin/env sh
# Bash script that copies plexreport files to various directories
# and walks the user through the initial setup

PATH=${PATH:-/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin}

PLEX_REPORT_LIB='/var/lib/plexReport'
PLEX_REPORT_CONF='/etc/plexReport'

echo "Creating plexreport library at /var/lib/plexReport"
mkdir -p $PLEX_REPORT_LIB
echo "Creating plexreport conf directory at /etc/plexReport"
mkdir -p $PLEX_REPORT_CONF

echo "Moving plexreport and plexreport-setup to /usr/local/sbin"
cp -r bin/* /usr/local/sbin
echo "Moving plexreport libraries to /var/lib/plexreport"
cp -r lib/* $PLEX_REPORT_LIB
echo "Moving email_body.erb to /etc/plexreport"
cp -r etc/* $PLEX_REPORT_CONF

echo "Creating /etc/plexreport/config.yaml"
touch /etc/plexReport/config.yaml
echo "Creating /var/log/plexReport.log"
touch /var/log/plexReport.log

GEM_BINARY=$(whereis gem | cut -d':' -f2 | cut -d' ' -f2)
if [ "$GEM_BINARY" = "" ]; then
    echo "Installing ruby"
    if [ "$(uname)" = "FreeBSD" ]; then
        pkg install -y ruby devel/ruby-gems
    else # RedHat/CentOS/Ubuntu/Debian
        . /etc/os-release
        case $NAME in
            "Red Hat Enterprise Linux Server"|"CentOS Linux") yum install -y ruby ruby-devel make gcc ;;
            "Debian GNU/Linux"|"Ubuntu") apt-get update && apt-get install -y ruby ruby-dev make gcc;;
        esac
    fi
    GEM_BINARY=$(whereis gem | cut -d':' -f2 | cut -d' ' -f2)
    if [ "$GEM_BINARY" = "" ]; then
       echo "Something went wrong while installing ruby!"
       exit 1
    fi
fi

echo "Installing ruby gem dependency"
$GEM_BINARY install bundler
BUNDLER=$(whereis bundle | cut -d':' -f2 | cut -d' ' -f2)
$BUNDLER install

if [ ! -e "/etc/plexReport/config.yaml" ]; then
    echo "Running /usr/local/sbin/plexreport-setup"
    /usr/local/sbin/plexreport-setup
else
    echo "Skipping setup: plexreport is alredy configured (/etc/plexReport/config.yaml)"
fi

# Add PATH only if crontab doesn't have it
if crontab -l | grep -q '^PATH'; then
    crontab -l > mycron
    sed "s|^PATH.*|PATH=$PATH|" -i mycron
else
    cat <<EOI > mycron
PATH=$PATH
$(crontab -l)
EOI
    crontab mycron
    rm mycron
fi

# Add plexReport crontab
if ! crontab -l | grep -q '/usr/local/sbin/plexreport$'; then
    echo "What day do you want to run the script on? (Put 0 for Sunday, 1 for Monday, etc...)"
    read CRON_DAY
    echo "What hour should the script run? (00-23)"
    read CRON_HOUR
    echo "What minute in that hour should the script run? (00-59)"
    read CRON_MINUTE

    echo "Adding /usr/local/sbin/plexreport to crontab"
    crontab -l > mycron

    echo "$CRON_MINUTE $CRON_HOUR * * $CRON_DAY /usr/local/sbin/plexreport" >> mycron

    # Add crontab
    crontab mycron
    rm mycron
else
    echo "Skipping crontab configuration - already added:"
    crontab -l
fi
echo "Setup complete!"
