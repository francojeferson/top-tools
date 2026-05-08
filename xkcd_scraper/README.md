# XKCD Comic Scraper

This tool automatically scrapes the latest XKCD comic from [xkcd.com](https://xkcd.com/) every 24 hours and saves it to
a local directory. It uses Python with libraries like `requests` for HTTP requests, `BeautifulSoup` for HTML parsing,
and `schedule` for task scheduling.

## Installation

1. **Ensure Python is Installed**: Make sure you have Python 3.8 or higher installed on your system. You can check this
   by running:

   ```py
   python --version
   ```

   If not installed, download it from [python.org](https://www.python.org/downloads/).

2. **Install Dependencies**: Navigate to the `xkcd_scraper` directory and install the required libraries using pip:

   ```py
   cd xkcd_scraper
   pip install -r requirements.txt
   ```

## Usage

1. **Run the Script**: Execute the script to start the scraper. It will fetch the latest comic and then exit:

   ```py
   python xkcd_scraper.py
   ```

2. **Check Saved Comics**: Comics are saved in the `comics` subdirectory within the `xkcd_scraper` folder. The file is
   named statically as `latest_xkcd.jpg`, overwriting the previous comic with each run.

3. **Logs**: Logs are output to the console (stdout) for cleaner project directory structure.

## Notes

- The script uses a user-agent header to mimic a browser request. If XKCD changes its website structure, the script
  might need updates to correctly parse the comic image URL.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
