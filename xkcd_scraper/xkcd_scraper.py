import requests
from bs4 import BeautifulSoup
import os
import sys
import logging

# Set up logging to track script execution and errors
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler()],
)
logger = logging.getLogger(__name__)

# Directory to save comics, relative to the script's location
COMICS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "comics")


def ensure_comics_dir():
    """Ensure the directory for saving comics exists."""
    if not os.path.exists(COMICS_DIR):
        os.makedirs(COMICS_DIR)
        logger.info(f"Created directory {COMICS_DIR} for saving comics.")


def fetch_latest_xkcd_comic():
    """Fetch and save the latest XKCD comic and its explanation from explainxkcd.com.

    Returns True on success and False on any failure. Nothing is written unless both
    the image and the explanation were fetched."""
    try:
        # URL of the XKCD homepage
        url = "https://xkcd.com/"
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }

        # Make HTTP GET request to fetch the page content
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()  # Raise an exception for bad status codes

        logger.info("Successfully fetched XKCD homepage.")

        # Parse the HTML content using BeautifulSoup
        soup = BeautifulSoup(response.text, "html.parser")

        # Find the comic image element
        comic_div = soup.find("div", id="comic")
        if not comic_div:
            logger.error("Could not find comic div on the page.")
            return False

        comic_img = comic_div.find("img")
        if not comic_img:
            logger.error("Could not find comic image in the comic div.")
            return False

        # Extract the image URL
        img_url = comic_img["src"]
        if not img_url.startswith("http"):
            img_url = "https:" + img_url

        # Extract comic number from the page title or meta information
        comic_number = ""
        title_tag = soup.find("div", id="ctitle")
        if title_tag:
            title_text = title_tag.text
            # Check if title contains the comic number
            import re

            match = re.search(r"#(\d+)", title_text)
            if match:
                comic_number = match.group(1)
        if not comic_number:
            # Fallback to URL path or other indicators
            prev_link = soup.find("a", rel="prev")
            if prev_link and "href" in prev_link.attrs:
                prev_href = prev_link["href"]
                match = re.search(r"/(\d+)/", prev_href)
                if match:
                    prev_number = int(match.group(1))
                    comic_number = str(prev_number + 1)
        if not comic_number.isdigit():
            logger.error("Could not extract comic number from page.")
            return False

        # Download the comic image (kept in memory; nothing is written until the
        # explanation is fetched too)
        logger.info(f"Downloading comic from {img_url}")
        img_response = requests.get(img_url, timeout=10)
        img_response.raise_for_status()

        # Fetch explanation from explainxkcd.com
        explanation_url = f"https://www.explainxkcd.com/wiki/index.php/{comic_number}"
        logger.info(f"Fetching explanation from {explanation_url}")
        explanation_response = requests.get(
            explanation_url, headers=headers, timeout=10
        )
        explanation_response.raise_for_status()

        explanation_soup = BeautifulSoup(explanation_response.text, "html.parser")
        explanation_section = explanation_soup.find("span", id="Explanation")
        if not explanation_section:
            logger.error("Could not find Explanation section on the page.")
            return False

        # Extract text from the Explanation section
        explanation_text = ""
        current_element = explanation_section.find_parent()
        while current_element and current_element.name != "span":
            if current_element.name in ["p", "div"]:
                explanation_text += current_element.get_text(strip=True) + "\n\n"
            current_element = current_element.find_next_sibling()
            if current_element and current_element.find("span", id="Transcript"):
                break

        # Both fetches worked. Use static filenames for the latest comic. Write both files
        # to temp files first, then rename them into place, so a failed write cannot
        # leave a new image next to old text.
        filepath = os.path.join(COMICS_DIR, "latest_xkcd.jpg")
        explanation_filepath = os.path.join(COMICS_DIR, "latest_xkcd_explanation.txt")
        with open(filepath + ".tmp", "wb") as f:
            f.write(img_response.content)
        with open(explanation_filepath + ".tmp", "w", encoding="utf-8") as f:
            f.write(explanation_text)
        os.replace(filepath + ".tmp", filepath)
        os.replace(explanation_filepath + ".tmp", explanation_filepath)

        logger.info(f"Successfully saved comic to {filepath}")
        logger.info(f"Successfully saved explanation to {explanation_filepath}")
        return True

    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching comic or explanation: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return False


def main():
    """Main function to initialize and run the scraper."""
    logger.info("Starting XKCD Scraper...")
    ensure_comics_dir()

    # Run the scraper immediately and exit. Failures were logged above; exit non-zero
    # so the CI job fails instead of reporting success.
    if not fetch_latest_xkcd_comic():
        sys.exit(1)
    logger.info(
        "Finished fetching the latest XKCD comic and explanation. Exiting script."
    )


if __name__ == "__main__":
    main()
