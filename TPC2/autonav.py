import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.webdriver import LocalWebDriver
from selenium.webdriver.support.wait import WebDriverWait
import selenium.webdriver.support.expected_conditions as EC

driver: LocalWebDriver = webdriver.Chrome() # type: ignore
wait = WebDriverWait(driver, timeout=5)

driver.get("https://www.saucedemo.com")

usernameField = driver.find_element(by=By.ID, value="user-name")
passwordField = driver.find_element(by=By.ID, value="password")
submitButton = driver.find_element(by=By.ID, value="login-button")
wait.until(lambda _: submitButton.is_displayed())

# usernameField.send_keys("standard_user")
# usernameField.send_keys("locked_out_user")
# usernameField.send_keys("problem_user")
# usernameField.send_keys("error_user")
# usernameField.send_keys("performance_glitch_user")
usernameField.send_keys("visual_user")
passwordField.send_keys("secret_sauce")
submitButton.click()

# inventoryContainer = driver.find_element(by=By.ID, value="inventory_container")
# wait.until(lambda _: inventoryContainer.is_displayed() or loginErrorElement.is_displayed())
INVENTORY_CONTAINER_SELECTOR = (By.ID, "inventory_container")
LOGIN_ERROR_MESSAGE_SELECTOR = (By.CSS_SELECTOR, ".error-message-container.error > h3")

wait.until(lambda _: \
    EC.presence_of_element_located(INVENTORY_CONTAINER_SELECTOR) \
        or EC.presence_of_element_located(LOGIN_ERROR_MESSAGE_SELECTOR)
)

print("Has login error:", EC.presence_of_element_located(LOGIN_ERROR_MESSAGE_SELECTOR))
if (len(elems := driver.find_elements(by=LOGIN_ERROR_MESSAGE_SELECTOR[0], value=LOGIN_ERROR_MESSAGE_SELECTOR[1])) > 0):
    loginErrorElement = elems[0]
    print(f"Could not login: {loginErrorElement.text}")
    sys.exit(1)

inventoryContainer = driver.find_element(by=INVENTORY_CONTAINER_SELECTOR[0], value=INVENTORY_CONTAINER_SELECTOR[1])
items = []
inventoryItems = inventoryContainer.find_elements(by=By.CLASS_NAME, value="inventory_item_description")
for item in inventoryItems:
    itemKey = item.find_element(by=By.CSS_SELECTOR, value=".inventory_item_label > a").text
    itemDesc = item.find_element(by=By.CLASS_NAME, value="inventory_item_desc").text
    itemPrice = item.find_element(by=By.CLASS_NAME, value="inventory_item_price").text
    items.append({
        "name": itemKey,
        "desc": itemDesc,
        "price": itemPrice
    })

print(f"Found {len(items)} items:")
for item in items:
    print(f"  name: {item['name']}")
    print(f"  desc: {item['desc']}")
    print(f"  price: {item['price']}")
    print("============================")

driver.quit()
