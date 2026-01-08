import unittest
from appium import webdriver
from appium.options.android import UiAutomator2Options


class MyTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """Runs once before all tests"""
        options = UiAutomator2Options()
        options.platform_name = "Android"
        options.automation_name = "UiAutomator2"
        options.device_name = "V2109"
        options.udid = "3414000171000BZ"
        options.app_package = "com.ameen.plus"
        options.app_activity = "com.ameen.plus.MainActivity"
        options.no_reset = True
        options.auto_grant_permissions = True

        cls.driver = webdriver.Remote(
            "http://127.0.0.1:4723",
            options=options
        )

    def test_app_launch(self):
        """Simple test to verify app launched"""
        self.assertIsNotNone(self.driver)
        print("✅ App launched successfully")

    @classmethod
    def tearDownClass(cls):
        """Runs once after all tests"""
        if cls.driver:
            cls.driver.quit()


if __name__ == '__main__':
    unittest.main()
