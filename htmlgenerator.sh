#!/bin/bash

create_content_from_csv() {
    local csv_file="$1"
    local html_file="table.html"

    # Comienza a escribir el archivo HTML
    cat <<EOL > "$html_file"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Useful Links - Rich</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #ffffff;
            color: #00796b;
            padding: 20px;
            margin: 0;
            box-sizing: border-box;
        }
        .useful-links-rich {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            justify-content: center;
        }
        .applogo {
            margin: 5px auto;
            height: 100px;
        }
        .link-box {
            width: 200px;
            height: 200px;
            border: 1px solid #dddddd;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            position: relative;
            text-align: center;
            background-color: #f9f9f9;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        .link-box img {
            width: 100px;
            height: 100px;
            cursor: pointer;
        }
        .link-box a {
            text-decoration: none;
            color: #00796b;
            margin-top: 10px;
            font-weight: bold;
            cursor: pointer;
        }
        .tooltip {
            display: none;
            position: absolute;
            width: 200px;
            background: rgba(0, 0, 0, 0.7);
            color: #fff;
            padding: 10px;
            border-radius: 5px;
            text-align: center;
            z-index: 1;
        }
        .link-box:hover .tooltip {
            display: block;
        }
    </style>
</head>
<body>
    <div class="useful-links-rich">
EOL

    # Leer el archivo CSV y generar contenido HTML
    while IFS=, read -r logo href name alt; do
        cp ${CONFIG_ROOT}/$logo ${WEB_ROOT} > /dev/null 2>&1
        cat <<EOL >> "$html_file"
        <div class="link-box" onmouseover="showTooltip(event, '$alt')" onmouseout="hideTooltip()">
            <a href="$href" target="_blank">
                <img src="$logo" alt="$alt" class="applogo">
            </a>
            <a href="$href" target="_blank">$name</a>
        </div>
EOL
    done < "$csv_file"

    # Finalizar el archivo HTML
    cat <<EOL >> "$html_file"
    </div>
    <div class="tooltip" id="tooltip"></div>
    <script>
        function showTooltip(event, name) {
            const tooltip = document.getElementById('tooltip');
            tooltip.innerText = name;
            tooltip.style.display = 'block';
            updateTooltipPosition(event);
        }

        function hideTooltip() {
            const tooltip = document.getElementById('tooltip');
            tooltip.style.display = 'none';
        }

        function updateTooltipPosition(event) {
            const tooltip = document.getElementById('tooltip');
            const pageX = event.pageX;
            const pageY = event.pageY;

            tooltip.style.left = (pageX + 10) + 'px';  // adjust tooltip right of cursor
            tooltip.style.top = (pageY + 5) + 'px';   // adjust tooltip under cursor
        }

        document.addEventListener('mousemove', function(event) {
            const tooltip = document.getElementById('tooltip');
            if (tooltip.style.display === 'block') {
                updateTooltipPosition(event);
            }
        });
    </script>
</body>
</html>
EOL

    echo "Archivo HTML generado: $html_file"
}

# Verificar si se proporcionó un archivo CSV como argumento
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <archivo_csv>"
    exit 1
fi

# Llamar a la función con el nombre del archivo CSV proporcionado
create_content_from_csv "$1"
