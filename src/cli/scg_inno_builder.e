note
	description: "[
		INNO Setup Installer Script Builder for Eiffel Applications.

		Generates .iss scripts for creating Windows installers with:
		- Application metadata (name, version, publisher)
		- Icon and logo customization
		- File inclusion patterns
		- Registry entries
		- Start menu shortcuts
		- Uninstaller support

		Follows simple_* ecosystem patterns.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_INNO_BUILDER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize builder with defaults.
		do
			create app_name.make_empty
			create app_version.make_from_string ("1.0.0")
			create publisher.make_empty
			create app_url.make_empty
			create exe_name.make_empty
			create output_base_filename.make_empty
			create default_dir_name.make_empty
			create icon_file.make_empty
			create license_file.make_empty
			create files_to_include.make (10)
			create registry_entries.make (5)
			compression := "lzma2"
			solid_compression := True
			create_desktop_icon := True
			create_start_menu := True
		end

feature -- Access

	app_name: STRING_32
			-- Application name

	app_version: STRING_32
			-- Application version (e.g., "1.0.0")

	publisher: STRING_32
			-- Publisher/company name

	app_url: STRING_32
			-- Application website URL

	exe_name: STRING_32
			-- Main executable name (e.g., "myapp.exe")

	output_base_filename: STRING_32
			-- Output installer filename (without extension)

	default_dir_name: STRING_32
			-- Default installation directory name

	icon_file: STRING_32
			-- Path to application icon (.ico)

	license_file: STRING_32
			-- Path to license file

	files_to_include: ARRAYED_LIST [TUPLE [source: STRING_32; dest: STRING_32; flags: STRING_32]]
			-- Files to include in installer

	registry_entries: ARRAYED_LIST [TUPLE [root: STRING_32; key: STRING_32; name: STRING_32; value: STRING_32]]
			-- Registry entries to create

	compression: STRING
			-- Compression method (lzma, lzma2, zip, bzip, none)

	solid_compression: BOOLEAN
			-- Use solid compression?

	create_desktop_icon: BOOLEAN
			-- Create desktop shortcut?

	create_start_menu: BOOLEAN
			-- Create start menu entries?

feature -- Configuration

	set_app_name (a_name: STRING_32)
			-- Set application name.
		require
			name_not_empty: not a_name.is_empty
		do
			app_name := a_name
		ensure
			app_name_set: app_name = a_name
		end

	set_app_version (a_version: STRING_32)
			-- Set application version.
		require
			version_not_empty: not a_version.is_empty
		do
			app_version := a_version
		ensure
			version_set: app_version = a_version
		end

	set_publisher (a_publisher: STRING_32)
			-- Set publisher name.
		do
			publisher := a_publisher
		ensure
			publisher_set: publisher = a_publisher
		end

	set_app_url (a_url: STRING_32)
			-- Set application URL.
		do
			app_url := a_url
		ensure
			url_set: app_url = a_url
		end

	set_exe_name (a_name: STRING_32)
			-- Set main executable name.
		require
			name_not_empty: not a_name.is_empty
		do
			exe_name := a_name
		ensure
			exe_set: exe_name = a_name
		end

	set_output_filename (a_name: STRING_32)
			-- Set output installer filename.
		require
			name_not_empty: not a_name.is_empty
		do
			output_base_filename := a_name
		ensure
			output_set: output_base_filename = a_name
		end

	set_default_dir (a_dir: STRING_32)
			-- Set default installation directory.
		require
			dir_not_empty: not a_dir.is_empty
		do
			default_dir_name := a_dir
		ensure
			dir_set: default_dir_name = a_dir
		end

	set_icon_file (a_path: STRING_32)
			-- Set application icon file path.
		do
			icon_file := a_path
		ensure
			icon_set: icon_file = a_path
		end

	set_license_file (a_path: STRING_32)
			-- Set license file path.
		do
			license_file := a_path
		ensure
			license_set: license_file = a_path
		end

	add_file (a_source, a_dest: STRING_32)
			-- Add file to include with default flags.
		require
			source_not_empty: not a_source.is_empty
			dest_not_empty: not a_dest.is_empty
		do
			files_to_include.extend ([a_source, a_dest, {STRING_32} "ignoreversion"])
		ensure
			file_added: files_to_include.count = old files_to_include.count + 1
		end

	add_file_with_flags (a_source, a_dest, a_flags: STRING_32)
			-- Add file with custom flags.
		require
			source_not_empty: not a_source.is_empty
			dest_not_empty: not a_dest.is_empty
		do
			files_to_include.extend ([a_source, a_dest, a_flags])
		ensure
			file_added: files_to_include.count = old files_to_include.count + 1
		end

	add_exe (a_source: STRING_32)
			-- Add main executable.
		require
			source_not_empty: not a_source.is_empty
		do
			add_file_with_flags (a_source, {STRING_32} "{app}", {STRING_32} "ignoreversion")
		end

	add_directory_recursive (a_source, a_dest: STRING_32)
			-- Add entire directory recursively.
		require
			source_not_empty: not a_source.is_empty
			dest_not_empty: not a_dest.is_empty
		do
			files_to_include.extend ([a_source + {STRING_32} "\*", a_dest, {STRING_32} "ignoreversion recursesubdirs createallsubdirs"])
		end

	add_registry_entry (a_root, a_key, a_name, a_value: STRING_32)
			-- Add registry entry.
		require
			root_valid: a_root.is_case_insensitive_equal ("HKLM") or a_root.is_case_insensitive_equal ("HKCU")
			key_not_empty: not a_key.is_empty
		do
			registry_entries.extend ([a_root, a_key, a_name, a_value])
		ensure
			entry_added: registry_entries.count = old registry_entries.count + 1
		end

	set_compression (a_method: STRING)
			-- Set compression method.
		require
			valid_method: a_method.is_case_insensitive_equal ("lzma") or
			              a_method.is_case_insensitive_equal ("lzma2") or
			              a_method.is_case_insensitive_equal ("zip") or
			              a_method.is_case_insensitive_equal ("bzip") or
			              a_method.is_case_insensitive_equal ("none")
		do
			compression := a_method
		ensure
			compression_set: compression = a_method
		end

	set_solid_compression (a_value: BOOLEAN)
			-- Enable/disable solid compression.
		do
			solid_compression := a_value
		ensure
			solid_set: solid_compression = a_value
		end

	set_create_desktop_icon (a_value: BOOLEAN)
			-- Enable/disable desktop icon creation.
		do
			create_desktop_icon := a_value
		ensure
			desktop_set: create_desktop_icon = a_value
		end

	set_create_start_menu (a_value: BOOLEAN)
			-- Enable/disable start menu creation.
		do
			create_start_menu := a_value
		ensure
			start_menu_set: create_start_menu = a_value
		end

feature -- Generation

	generate_iss_script: STRING_32
			-- Generate complete INNO Setup script.
		require
			app_name_set: not app_name.is_empty
			exe_name_set: not exe_name.is_empty
		do
			create Result.make (4000)

			-- Setup section
			Result.append (generate_setup_section)
			Result.append ({STRING_32} "%N")

			-- Languages section
			Result.append (generate_languages_section)
			Result.append ({STRING_32} "%N")

			-- Tasks section
			Result.append (generate_tasks_section)
			Result.append ({STRING_32} "%N")

			-- Files section
			Result.append (generate_files_section)
			Result.append ({STRING_32} "%N")

			-- Icons section
			Result.append (generate_icons_section)
			Result.append ({STRING_32} "%N")

			-- Registry section (if any)
			if not registry_entries.is_empty then
				Result.append (generate_registry_section)
				Result.append ({STRING_32} "%N")
			end

			-- Run section
			Result.append (generate_run_section)
		ensure
			result_not_empty: not Result.is_empty
		end

	generate_and_save (a_output_path: STRING_32): BOOLEAN
			-- Generate script and save to file.
		require
			path_not_empty: not a_output_path.is_empty
		local
			l_file: SIMPLE_FILE
			l_script: STRING_32
		do
			l_script := generate_iss_script
			create l_file.make (a_output_path)
			Result := l_file.set_content (l_script)
		end

feature {NONE} -- Implementation

	generate_setup_section: STRING_32
			-- Generate [Setup] section.
		local
			l_guid: STRING
		do
			create Result.make (1000)
			Result.append ({STRING_32} "[Setup]%N")

			-- Generate a simple GUID placeholder (user should replace)
			l_guid := generate_app_id

			Result.append ({STRING_32} "AppId={{")
			Result.append_string_general (l_guid)
			Result.append ({STRING_32} "}%N")

			Result.append ({STRING_32} "AppName=")
			Result.append (app_name)
			Result.append ({STRING_32} "%N")

			Result.append ({STRING_32} "AppVersion=")
			Result.append (app_version)
			Result.append ({STRING_32} "%N")

			if not publisher.is_empty then
				Result.append ({STRING_32} "AppPublisher=")
				Result.append (publisher)
				Result.append ({STRING_32} "%N")
			end

			if not app_url.is_empty then
				Result.append ({STRING_32} "AppPublisherURL=")
				Result.append (app_url)
				Result.append ({STRING_32} "%N")
				Result.append ({STRING_32} "AppSupportURL=")
				Result.append (app_url)
				Result.append ({STRING_32} "%N")
			end

			Result.append ({STRING_32} "DefaultDirName={autopf}\")
			if not default_dir_name.is_empty then
				Result.append (default_dir_name)
			else
				Result.append (app_name)
			end
			Result.append ({STRING_32} "%N")

			Result.append ({STRING_32} "DefaultGroupName=")
			Result.append (app_name)
			Result.append ({STRING_32} "%N")

			if not license_file.is_empty then
				Result.append ({STRING_32} "LicenseFile=")
				Result.append (license_file)
				Result.append ({STRING_32} "%N")
			end

			Result.append ({STRING_32} "OutputDir=output%N")

			if not output_base_filename.is_empty then
				Result.append ({STRING_32} "OutputBaseFilename=")
				Result.append (output_base_filename)
			else
				Result.append ({STRING_32} "OutputBaseFilename=")
				Result.append (app_name)
				Result.append ({STRING_32} "_setup")
			end
			Result.append ({STRING_32} "%N")

			if not icon_file.is_empty then
				Result.append ({STRING_32} "SetupIconFile=")
				Result.append (icon_file)
				Result.append ({STRING_32} "%N")
			end

			Result.append ({STRING_32} "Compression=")
			Result.append_string_general (compression)
			Result.append ({STRING_32} "%N")

			Result.append ({STRING_32} "SolidCompression=")
			if solid_compression then
				Result.append ({STRING_32} "yes%N")
			else
				Result.append ({STRING_32} "no%N")
			end

			Result.append ({STRING_32} "WizardStyle=modern%N")
			Result.append ({STRING_32} "PrivilegesRequired=admin%N")
		end

	generate_languages_section: STRING_32
			-- Generate [Languages] section.
		do
			create Result.make (200)
			Result.append ({STRING_32} "[Languages]%N")
			Result.append ({STRING_32} "Name: %"english%"; MessagesFile: %"compiler:Default.isl%"%N")
		end

	generate_tasks_section: STRING_32
			-- Generate [Tasks] section.
		do
			create Result.make (300)
			Result.append ({STRING_32} "[Tasks]%N")
			if create_desktop_icon then
				Result.append ({STRING_32} "Name: %"desktopicon%"; Description: %"{cm:CreateDesktopIcon}%"; GroupDescription: %"{cm:AdditionalIcons}%"; Flags: unchecked%N")
			end
		end

	generate_files_section: STRING_32
			-- Generate [Files] section.
		do
			create Result.make (500)
			Result.append ({STRING_32} "[Files]%N")

			across files_to_include as ic loop
				Result.append ({STRING_32} "Source: %"")
				Result.append (ic.source)
				Result.append ({STRING_32} "%"; DestDir: %"")
				Result.append (ic.dest)
				Result.append ({STRING_32} "%"; Flags: ")
				Result.append (ic.flags)
				Result.append ({STRING_32} "%N")
			end
		end

	generate_icons_section: STRING_32
			-- Generate [Icons] section.
		do
			create Result.make (400)
			Result.append ({STRING_32} "[Icons]%N")

			-- Start menu icon
			if create_start_menu then
				Result.append ({STRING_32} "Name: %"{autoprograms}\")
				Result.append (app_name)
				Result.append ({STRING_32} "%"; Filename: %"{app}\")
				Result.append (exe_name)
				Result.append ({STRING_32} "%"%N")
			end

			-- Desktop icon
			if create_desktop_icon then
				Result.append ({STRING_32} "Name: %"{autodesktop}\")
				Result.append (app_name)
				Result.append ({STRING_32} "%"; Filename: %"{app}\")
				Result.append (exe_name)
				Result.append ({STRING_32} "%"; Tasks: desktopicon%N")
			end
		end

	generate_registry_section: STRING_32
			-- Generate [Registry] section.
		do
			create Result.make (300)
			Result.append ({STRING_32} "[Registry]%N")

			across registry_entries as ic loop
				Result.append ({STRING_32} "Root: ")
				Result.append (ic.root)
				Result.append ({STRING_32} "; Subkey: %"")
				Result.append (ic.key)
				Result.append ({STRING_32} "%"")
				if not ic.name.is_empty then
					Result.append ({STRING_32} "; ValueName: %"")
					Result.append (ic.name)
					Result.append ({STRING_32} "%"")
				end
				if not ic.value.is_empty then
					Result.append ({STRING_32} "; ValueData: %"")
					Result.append (ic.value)
					Result.append ({STRING_32} "%"; ValueType: string")
				end
				Result.append ({STRING_32} "; Flags: uninsdeletekey%N")
			end
		end

	generate_run_section: STRING_32
			-- Generate [Run] section.
		do
			create Result.make (200)
			Result.append ({STRING_32} "[Run]%N")
			Result.append ({STRING_32} "Filename: %"{app}\")
			Result.append (exe_name)
			Result.append ({STRING_32} "%"; Description: %"{cm:LaunchProgram,")
			Result.append (app_name)
			Result.append ({STRING_32} "}%"; Flags: nowait postinstall skipifsilent%N")
		end

	generate_app_id: STRING
			-- Generate a simple deterministic app ID based on app name.
		local
			l_hash: NATURAL_32
			i: INTEGER
		do
			-- Simple hash of app name for reproducible GUID
			l_hash := 0
			across app_name as ic loop
				l_hash := l_hash * 31 + ic.code.to_natural_32
			end

			create Result.make (36)
			Result.append (l_hash.to_hex_string)
			Result.append ("-0000-0000-0000-")
			-- Pad with zeros for valid GUID format
			from i := Result.count until i >= 36 loop
				Result.append ("0")
				i := i + 1
			end
		end

feature -- Prompt Template

	inno_prompt_template: STRING_32
			-- Template for generating INNO installer prompt.
		once
			create Result.make (2000)
			Result.append ({STRING_32} "=== INNO INSTALLER GENERATION ===%N%N")
			Result.append ({STRING_32} "Generate an INNO Setup installer script for the Eiffel application.%N%N")
			Result.append ({STRING_32} "REQUIRED INFORMATION:%N")
			Result.append ({STRING_32} "1. Application name and version%N")
			Result.append ({STRING_32} "2. Publisher/company name%N")
			Result.append ({STRING_32} "3. Main executable name%N")
			Result.append ({STRING_32} "4. Files to include%N")
			Result.append ({STRING_32} "5. Icon file path (optional)%N")
			Result.append ({STRING_32} "6. License file path (optional)%N%N")
			Result.append ({STRING_32} "OUTPUT FORMAT:%N")
			Result.append ({STRING_32} "```json%N")
			Result.append ({STRING_32} "{%N")
			Result.append ({STRING_32} "  %"type%": %"inno_installer%",%N")
			Result.append ({STRING_32} "  %"app_name%": %"MyApp%",%N")
			Result.append ({STRING_32} "  %"app_version%": %"1.0.0%",%N")
			Result.append ({STRING_32} "  %"publisher%": %"My Company%",%N")
			Result.append ({STRING_32} "  %"exe_name%": %"myapp.exe%",%N")
			Result.append ({STRING_32} "  %"icon_file%": %"path/to/icon.ico%",%N")
			Result.append ({STRING_32} "  %"files%": [%N")
			Result.append ({STRING_32} "    {%"source%": %"bin/myapp.exe%", %"dest%": %"{app}%"},%N")
			Result.append ({STRING_32} "    {%"source%": %"lib/*%", %"dest%": %"{app}/lib%"}%N")
			Result.append ({STRING_32} "  ],%N")
			Result.append ({STRING_32} "  %"create_desktop_icon%": true,%N")
			Result.append ({STRING_32} "  %"create_start_menu%": true%N")
			Result.append ({STRING_32} "}%N")
			Result.append ({STRING_32} "```%N")
		end

invariant
	files_list_exists: files_to_include /= Void
	registry_list_exists: registry_entries /= Void

end
