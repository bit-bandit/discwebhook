scriptname='discwebhook'
CONFIGDIR=${CONFIGDIR:-"$HOME/.$scriptname"};

dontdraw=0;
menu=0;

clear;

containsElement () {
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}

sed_apostophe_escape="s/'/'\"'\"'/g"

escapeApostrophe() {
	echo "$1" | sed -r "$sed_apostophe_escape"
}

saveWebhook() {
	local filename="$1";
	local url="$2";
	local username="$3";
	local avatar_url="$4";

	echo "# Webhook definition for $scriptname." > "$filename";
	echo "# Recreated from scratch every time an edit is made." > "$filename";
	echo "# Invisible to $scriptname until named in the 'webhooks' array in $scriptname.cfg" >> "$filename";
	echo "" >> "$filename";

	local p_username=$(escapeApostrophe "$username");
	local p_avatar_url=$(escapeApostrophe "$avatar_url");

	echo "webhook_url='$url'" >> "$filename";
	echo "username='$p_username'" >> "$filename";
	echo "avatar_url='$p_avatar_url'" >> "$filename";
}

newWebhook() {
	clear;
	echo "New webhook setup"

	echo "Name this webhook (e.g. 'Server - #general')"
	echo "An empty line cancels."
	read -e -p "Typing an existing name will load that webhook: " name <&1;

	if [ -z "$name" ]; then
		echo "Name required.";
		return 1;
	fi

	local filename="$CONFIGDIR/$name.dwh";

	echo $filename;

	if [ -f "$filename" ]; then
		if ! containsElement "$name" "${webhooks[@]}"; then
			webhooks+=("$name");
		fi

		return 0;
	fi

	clear;
	echo "New webhook setup"

	local url="";
	read -e -p "Paste in Discord Webhook URL: " url <&1;

	if [ -z "$url" ]; then
		echo "Discord Webhook URL required to use.";
		return 1;
	fi

	clear;
	echo "New webhook setup"

	read -e -p "Type in username [$scriptname]: " username_tmp <&1;
	username=${username_tmp:-$scriptname}

	clear;
	echo "New webhook setup"

	read -e -p "Type in an avatar URL (optional): " avatar_url_tmp <&1;
	avatar_url=${avatar_url_tmp:-'https://cdn.discordapp.com/embed/avatars/0.png'}

	webhooks+=("$name");

	saveWebhook "$filename" "$url" "$username" "$avatar_url";

	return 0;
}

syncEnvironment () {
	echo "# This file is replaced on every run of $scriptname!" > "$CONFIGDIR/.env";
	echo "# Don't add custom data to this file if you don't want it to disappear suddenly." >> "$CONFIGDIR/.env";
	echo "" >> "$CONFIGDIR/.env";

	local webhookarraystr='';
	for webhook_index in "${!webhooks[@]}"; do # iterate webhooks
		hookname="${webhooks[$webhook_index]}"
		p_hookname=$(escapeApostrophe "$hookname")

		webhookarraystr+=" '$p_hookname'";
	done
	webhookarraystr=${webhookarraystr:1};

	local p_curWebhook=$(escapeApostrophe "$curWebhook")

	echo "webhooks=($webhookarraystr)" >> "$CONFIGDIR/.env";
	echo "curWebhook='$p_curWebhook'" >> "$CONFIGDIR/.env";
}

if [ ! -d "$CONFIGDIR" ]; then
	mkdir "$CONFIGDIR";
fi

if [ ! -f "$CONFIGDIR/.env" ]; then
	touch "$CONFIGDIR/.env";
	chmod +x "$CONFIGDIR/.env";
fi

. "$CONFIGDIR/.env";

if [ ${#webhooks[@]} == 0 ]; then
	webhooks=();

	newWebhook;

	if [[ $? == 1 ]]; then
		exit;
	fi
fi

if [ -z "$curWebhook" ]; then
	curWebhook="${webhooks[0]}";
fi

. "$CONFIGDIR/$curWebhook.dwh";

if [ -z "$webhook_url" ]; then
	clear;
	read -e -p "Paste in Discord Webhook URL: " webhook_url_tmp <&1;

	if [ -z "$webhook_url_tmp" ]; then
		echo "Discord Webhook URL required to use.";
		return 1;
	fi

	webhook_url=${webhook_url_tmp:-$webhook_url}
fi

if [ -z "$username" ]; then
	clear;
	read -e -p "Type in username [$scriptname]: " username_tmp <&1;
	username=${username_tmp:-$scriptname}
fi

if [ -z "$avatar_url" ]; then
	clear;
	read -e -p "Type in an avatar URL (optional): " avatar_url_tmp <&1;
	avatar_url=${avatar_url_tmp:-"https://cdn.discordapp.com/embed/avatars/0.png"}
fi

syncEnvironment;

draw() {
	clear;

	case $menu in

	0) # Main menu
		echo "Discord Webhook data sender";
		echo "1) Send message";
		echo "2) Change username";
		echo "3) Change avatar URL";
		echo "4) Update webhook URL";
		echo "5) Manage webhooks";
		echo "q) Quit";
		echo "";
		echo "Username: $username";
		echo "Avatar URL: $avatar_url";
		echo "Webhook: $curWebhook";
		#echo "Last key number: $lastkey";
		echo "";
		;;

	1) # Message send menu
		echo "Press RETURN to send your message.";
		echo "Press RETURN with an empty message to return to main menu.";
		echo "The '/send <message>' command doesn't require <message>.";
		echo "";
		echo "Username: $username";
		echo "Avatar URL: $avatar_url";
		echo "Webhook: $curWebhook";
		echo "";

		[[ "$cmd_tts" -eq 1 ]] \
			&& echo "TTS enabled: true (use '/tts' to disable)" \
			|| echo "TTS enabled: false (use '/tts' to enable)";

		echo ""

		[ -z "$cmd_embed" ] \
			&& echo "Embed JSON: (empty, use '/embed <json>' to write.)" \
			|| echo "Embed JSON: \`$cmd_embed\` (use '/embed' to clear)";

		echo "";
		;;

	2) # Username change menu
		echo "Press RETURN to set username and return to main menu.";
		echo "Current username: $username";
		echo "";
		;;
	3) # Avatar URL change menu
		echo "Press RETURN to set avatar URL and return to main menu.";
		echo "Current URL: $avatar_url";
		echo "";
		;;
	4) # Webhook URL change menu
		echo "Press RETURN to set webhook URL and return to main menu.";
		echo "";
		;;
	5) # Webhook management menu
		echo "Pick an option:";
		echo "Webhook: $curWebhook";
		echo "";

		for webhook_index in "${!webhooks[@]}"; do # iterate webhooks
			echo """$(($webhook_index + 1))"") Use webhook '""${webhooks[$webhook_index]}""'";
		done

		echo "a) Add webhook";
		echo "l) Load webhook from config folder";
		echo "d) Delete webhook";
		echo "r) Rename webhook";
		echo "q) Go back to main menu";
		echo "";
		;;

	# hidden menus! can't access with 1 keypress.

	51) # Webhook delete menu
		echo "Pick an option:";
		echo "Webhook: $curWebhook";
		echo "";

		for webhook_index in "${!webhooks[@]}"; do # iterate webhooks
			echo """$(($webhook_index + 1))"") Delete webhook '""${webhooks[$webhook_index]}""'";
		done

		echo "q) Go back to main menu";
		echo "";
		;;

	52) # Webhook rename menu
		echo "Pick an option:";
		echo "Webhook: $curWebhook";
		echo "";

		for webhook_index in "${!webhooks[@]}"; do # iterate webhooks
			echo """$(($webhook_index + 1))"") Rename webhook '""${webhooks[$webhook_index]}""'";
		done

		echo "q) Go back to main menu";
		echo "";
		;;

	*) # Something messed up badly!
		menu=0; # We're going back to the main menu.
		draw; # And drawing it again!
		;;

	esac
};

curl_sed_apostophe_escape='s/"/\\"/g'

curlEscapeQuotes() {
	echo "$1" | sed -r "$curl_sed_apostophe_escape"
}

while :; do
	# Menu drawing.

	if [[ $dontdraw == 0 ]]; then
		draw;
	fi

	dontdraw=0; # If set to 1, will not redraw this update.

	# Menu input handling, update logic, and action handler.
	# Does the stuff.

	case $menu in

	0) # Main menu
		read -n 1 -p "Your choice: " key <&1;

		#[[ $(printf "%d" "'$key") != 127 ]];
		#lastkey=$(echo $?);

		# the weird first check checks if it's even a number so it doesnt throw errors
		# determine if key is between 1 and 5
		if [ ! -z "${key##*[!0-9]*}" ] && (( $key >= 1 )) && (( $key <= 5 )); then
			menu=$key;
		# the quit key
		elif [[ $key == 'q' ]]; then
			echo;
			exit;
		fi
		;;

	1) # Message send menu
		read -e -p ": " content <&1; # Read the contents of a message

		# Initialise text to speech boolean if unset
		if [ -z "$cmd_tts" ]; then
			cmd_tts=0;
		fi

		cmd_send=0;

		# This matches '/command arg1'.
		match="^(/[[:lower:]]+) *(.*)";

		# This is a command? See if it's one of our cool ones.
		if [[ $content =~ $match ]]; then
			command=${BASH_REMATCH[1]}; # Get first match as $command
			arg=${BASH_REMATCH[2]}; # Get second match as $arg

			case $command in

			/embed) # /embed <json>
				cmd_embed="$arg"
				content=""
				continue
				;;

			/tts) # /tts
				cmd_tts=$(( ~$cmd_tts & 1 )) # flip truth
				content=""
				continue
				;;

			/send) # /send <message>
				cmd_send=1 # flip truth
				content="$arg"
				;;

			*)
				;;

			esac
		fi

		if [ ${#content} -gt 0 ] || [[ $cmd_send -eq 1 ]]; then
			json=""

			if [ -n "$content" ]; then
				p_content=$(curlEscapeQuotes "$content")
				json+="\"content\": \"$p_content\", "
			fi

			p_username=$(curlEscapeQuotes "$username")
			p_avatar_url=$(curlEscapeQuotes "$avatar_url")

			json+="\"username\": \"$p_username\", "
			json+="\"avatar_url\": \"$p_avatar_url\", "

			if [ -n "$cmd_embed" ]; then
				json+="\"embeds\": $cmd_embed, "
			fi

			[[ "$cmd_tts" -eq 1 ]] && json+="\"tts\": true, "

			json=${json:0:-2}
			json='{'$json'}'

			http_code=$(curl -s \
				-X POST -H "Content-Type: application/json" \
				--data "$json" \
				-o "$CONFIGDIR/.resp" -w '%{http_code}' \
				"$webhook_url" \
			);

			response=$(cat "$CONFIGDIR/.resp")
			rm "$CONFIGDIR/.resp"

			if (( $http_code < 200 )) || (( $http_code > 299 )); then
				echo ""
				printf "The sent JSON: \`%s\`" "$json"
				echo ""
				printf "Got HTTP code %d (not 2xx); the response follows:\n" "$http_code"
				echo ""
				printf "%s\n" "$response"
				echo ""

				read -n 1 -p "Press any key to continue . . . ";
			fi

			unset $tts;

			if [ ! $? ]; then
				dontdraw=1;
			fi

			content="";
		else
			menu=0;
		fi
		;;

	2) # Username change menu
		read -e -p ": " username_tmp <&1;

		username=${username_tmp:-$username};
		saveWebhook "$CONFIGDIR/$curWebhook.dwh" "$webhook_url" "$username" "$avatar_url"

		menu=0;
		;;

	3) # Avatar URL change menu
		read -e -p ": " avatar_url_tmp <&1;

		avatar_url=${avatar_url_tmp:-$avatar_url};
		saveWebhook "$CONFIGDIR/$curWebhook.dwh" "$webhook_url" "$username" "$avatar_url"

		menu=0;
		;;

	4) # Webhook URL update menu
		read -e -p ": " webhook_url_tmp <&1;

		webhook_url=${webhook_url_tmp:-$webhook_url};
		saveWebhook "$CONFIGDIR/$curWebhook.dwh" "$webhook_url" "$username" "$avatar_url"

		menu=0;
		;;

	5) # Webhook management menu
		read -n 1 -p "Your choice: " key <&1;

		# the weird first check checks if it's even a number so it doesnt throw errors
		# determine if key is between 1 and 3
		if [ ! -z "${key##*[!0-9]*}" ] && (( $key >= 1 )) && (( $key <= "${#webhooks[@]}" )); then
			key=$((key - 1));

			curWebhook="${webhooks[$key]}";

			. "$CONFIGDIR/$curWebhook.dwh";
			syncEnvironment;
		# the add webhook key
		elif [[ $key == 'a' ]]; then
			newWebhook;
			syncEnvironment;
		# the load webhook key
		elif [[ $key == 'l' ]]; then
			pwd=$PWD
			cd $CONFIGDIR

			clear;

			select fname in *.dwh; do
				if [ -z "$fname" ]; then
					break;
				fi

				# get the pre-extension, post-directory name of the file.
				fname=$(basename "$fname");

				extension='.dwh';
				name=${fname:0:$((${#fname} - ${#extension}))};

				for webhook_index in "${!webhooks[@]}"; do # iterate webhooks
					if [[ "${webhooks[$webhook_index]}" == "$name" ]]; then
						break 2
					fi
				done

				webhooks+=("$name");
				curWebhook="$name";

				. "$CONFIGDIR/$curWebhook.dwh";
				syncEnvironment;

				break;
			done

			cd $pwd
		# the rename webhook key
		elif [[ $key == 'd' ]]; then
			menu=51;
		# the rename webhook key
		elif [[ $key == 'r' ]]; then
			menu=52;
		# the quit key
		elif [[ $key == 'q' ]]; then
			menu=0;
		fi
		;;

	# hidden menus! can't access with 1 keypress.

	51) # Webhook delete menu
		read -n 1 -p "Your choice: " key <&1;

		# the weird first check checks if it's even a number so it doesnt throw errors
		# determine if key is between 1 and the number of webhooks
		if [ ! -z "${key##*[!0-9]*}" ] && (( $key >= 1 )) && (( $key <= ${#webhooks[@]} )); then
			if [[ ${#webhooks[@]} -eq 1 ]]; then
				echo ""
				echo ""
				echo "Cannot delete the last webhook.";
				read -n 1 -p "Press any key to continue . . . ";
				continue;
			fi

			key=$((key - 1));

			echo ""
			echo ""
			read -n 1 -p "Really delete webhook '${webhooks[$key]}'? (keeps file) [y/N]: " key_tmp <&1;

			if [[ $key_tmp == 'y' ]]; then
				echo "";
				read -n 1 -p "Remove the file for it too? [Y/n]: " key_tmp <&1;

				if [[ $curWebhook == ${webhooks[$key]} ]]; then
					if [[ $key == 0 ]]; then
						curWebhook=${webhooks[(($key + 1))]}
					else
						curWebhook=${webhooks[(($key - 1))]};
					fi
				fi

				if [[ $key_tmp == 'y' ]]; then
					rm "$CONFIGDIR/""${webhooks[$key]}"".dwh";
				fi

				new_array=();

				for webhook_index in "${!webhooks[@]}"; do # iterate webhooks
					[[ $webhook_index != $key ]] && new_array+=("${webhooks[$webhook_index]}");
				done

				webhooks=("${new_array[@]}");
				unset new_array;

				if [[ ${#webhooks[@]} -eq 0 ]]; then
					newWebhook;
				fi

				syncEnvironment;
			fi
		# the quit key
		elif [[ $key == 'q' ]]; then
			menu=5;
		fi
		;;

	52) # Webhook rename menu
		read -n 1 -p "Your choice: " key <&1;

		# the weird first check checks if it's even a number so it doesnt throw errors
		# determine if key is between 1 and 3
		if [ ! -z "${key##*[!0-9]*}" ] && (( $key >= 1 )) && (( $key <= "${#webhooks[@]}" )); then
			key=$((key - 1));

			clear;
			echo "Press RETURN to set new webhook name and return to webhook renaming menu.";
			echo "Current webhook name: ${webhooks[$key]}";
			echo "";

			read -e -p ": " newname <&1;

			if [[ $newname != ${webhooks[$key]} ]]; then
				if [ ${#newname} -ge 1 ]; then
					if [ -f "$CONFIGDIR/""$newname"".dwh" ]; then
						read -n 1 -p "Webhook '$newname' already exists. Replace? [y/N]: " key_tmp <&1;

						if [[ $key_tmp == 'y' ]]; then
							mv "$CONFIGDIR/""${webhooks[$key]}"".dwh" "$CONFIGDIR/""$newname"".dwh";

							if [[ ${webhooks[$key]} == $curWebhook ]]; then
								curWebhook=$newname;
							fi

							webhooks[$key]=$newname;
							syncEnvironment;
						else
							menu=5;
						fi
					else
						mv "$CONFIGDIR/""${webhooks[$key]}"".dwh" "$CONFIGDIR/""$newname"".dwh";

						if [[ ${webhooks[$key]} == $curWebhook ]]; then
							curWebhook=$newname;
						fi

						webhooks[$key]=$newname;
						syncEnvironment;
					fi
				fi
			fi
		# the quit key
		elif [[ $key == 'q' ]]; then
			menu=5;
		fi
		;;

	*) # A menu that doesn't exist?
		menu=0; # Something must've really messed up if we're here, fix it!
		;;

	esac
done
