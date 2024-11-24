#!/bin/bash

RPM_FILE=$1

if [ -z "$RPM_FILE" ]; then
  echo "Usage: $0 <package-file.rpm>"
  exit 1
fi

echo "Extracting scripts from $RPM_FILE..."

# Extract all scripts into a temporary file
rpm -qp --scripts "$RPM_FILE" > all_scripts.txt

# Split the scripts into separate files based on headers
csplit --digits=2 --quiet --prefix=script_ all_scripts.txt '/scriptlet (/' '{*}'

# Create proper scripts with shebangs
for file in script_*; do
  # Determine the type of scriptlet (preinstall, postinstall, etc.)
  if grep -q "preinstall scriptlet" "$file"; then
    output_file="preinstall.sh"
  elif grep -q "postinstall scriptlet" "$file"; then
    output_file="postinstall.sh"
  elif grep -q "preuninstall scriptlet" "$file"; then
    output_file="preuninstall.sh"
  elif grep -q "postuninstall scriptlet" "$file"; then
    output_file="postuninstall.sh"
  else
    rm "$file" # Remove unexpected or empty files
    continue
  fi

  # Extract the interpreter (e.g., /bin/sh) and add a shebang
  interpreter=$(grep -oP '(?<=scriptlet \(using ).*?(?=\))' "$file")
  if [ -n "$interpreter" ]; then
    echo "#!$interpreter" > "$output_file"
  else
    echo "#!/bin/sh" > "$output_file" # Default to /bin/sh if no interpreter is found
  fi

  # Append the script content, skipping the header line
  sed '1d' "$file" >> "$output_file"

  # Clean up the temporary split file
  rm "$file"
done

# Make the extracted scripts executable
chmod +x preinstall.sh postinstall.sh preuninstall.sh postuninstall.sh 2>/dev/null

echo "Scripts extracted:"
ls -1 preinstall.sh postinstall.sh preuninstall.sh postuninstall.sh 2>/dev/null
