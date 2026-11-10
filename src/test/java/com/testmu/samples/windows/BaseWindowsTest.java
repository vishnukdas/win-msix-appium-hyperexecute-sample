package com.testmu.samples.windows;

import io.appium.java_client.AppiumBy;
import io.appium.java_client.AppiumDriver;
import io.appium.java_client.remote.options.BaseOptions;
import org.openqa.selenium.By;
import org.openqa.selenium.NoSuchElementException;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.testng.ITestResult;
import org.testng.annotations.AfterMethod;
import org.testng.annotations.BeforeMethod;

import java.io.IOException;
import java.lang.reflect.Method;
import java.net.URI;
import java.net.URL;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.Properties;

import static org.testng.Assert.assertEquals;

/**
 * Starts a fresh Appium WinCore session against the MSIX installed by scripts/install-msix.ps1.
 * The app's AUMID comes from build/{@link #installedAppEnv()}, or the APP_ID env var.
 */
public abstract class BaseWindowsTest {

    protected AppiumDriver driver;
    protected Properties app;

    private static final Path RESULTS_DIR = Paths.get("build", "test-results", "screenshots");

    /** Env file under build/ written by scripts/install-msix.ps1 for this test's app. */
    protected String installedAppEnv() {
        return "installed-app.env";
    }

    @BeforeMethod
    public void startSession(Method test) throws IOException {
        System.out.println();
        System.out.println("[TEST] START " + getClass().getSimpleName() + "." + test.getName());
        app = loadInstalledApp();

        BaseOptions<?> options = new BaseOptions<>()
                .setPlatformName("Windows")
                .setAutomationName("Wincore")
                // A packaged (MSIX) app is launched by its Application User Model ID, not an .exe path.
                .amend("appium:app", app.getProperty("APP_ID"))
                .amend("appium:ms:waitForAppLaunch", 30)
                .setNewCommandTimeout(Duration.ofSeconds(120));

        String appiumUrl = System.getenv().getOrDefault("APPIUM_URL", "http://127.0.0.1:4723");
        waitForAppium(appiumUrl);
        step("Launch " + app.getProperty("APP_ID"));
        driver = new AppiumDriver(new URL(appiumUrl), options);
        waitUntilReady();
        step("App is ready");
    }

    /** Logs a test step to stdout, so it shows up in the Maven / CI output. */
    protected static void step(String message) {
        System.out.println("[STEP] " + message);
    }

    /** Hook for apps that render asynchronously (e.g. React Native): block until the UI is usable. */
    protected void waitUntilReady() {
    }

    protected WebElement waitFor(By locator) {
        return new WebDriverWait(driver, Duration.ofSeconds(30))
                .ignoring(NoSuchElementException.class)
                .until(d -> d.findElement(locator));
    }

    protected WebElement byId(String automationId) {
        return waitFor(AppiumBy.accessibilityId(automationId));
    }

    protected void click(String automationId) {
        step("Click " + automationId);
        byId(automationId).click();
    }

    /** React Native re-renders asynchronously after a click, so poll until the text settles. */
    protected void assertText(String automationId, String expected) {
        String actual = null;
        try {
            actual = new WebDriverWait(driver, Duration.ofSeconds(10))
                    .ignoring(NoSuchElementException.class)
                    .until(d -> {
                        String text = d.findElement(AppiumBy.accessibilityId(automationId)).getText();
                        return expected.equals(text) ? text : null;
                    });
        } catch (org.openqa.selenium.TimeoutException e) {
            actual = byId(automationId).getText();
        }
        assertEquals(actual, expected, automationId);
        step("Verified " + automationId + " = \"" + expected + "\"");
    }

    protected void typeInto(String automationId, String value) {
        step("Type \"" + value + "\" into " + automationId);
        WebElement field = byId(automationId);
        field.click();
        field.sendKeys(value);
    }

    @AfterMethod(alwaysRun = true)
    public void stopSession(ITestResult result) throws IOException {
        try {
            quitApp(result);
        } finally {
            String status = switch (result.getStatus()) {
                case ITestResult.SUCCESS -> "PASS";
                case ITestResult.FAILURE -> "FAIL";
                default -> "SKIP";
            };
            System.out.printf("[TEST] %s %s.%s (%.1fs)%s%n", status, getClass().getSimpleName(), result.getName(),
                    (result.getEndMillis() - result.getStartMillis()) / 1000.0,
                    result.getThrowable() == null ? "" : ": " + result.getThrowable());
        }
    }

    private void quitApp(ITestResult result) throws IOException {
        if (driver == null) {
            return;
        }
        try {
            Files.createDirectories(RESULTS_DIR);
            byte[] png = driver.getScreenshotAs(OutputType.BYTES);
            String status = result.isSuccess() ? "pass" : "fail";
            Path file = RESULTS_DIR.resolve(getClass().getSimpleName() + "-" + result.getName() + "-" + status + ".png");
            Files.write(file, png);
            step("Saved screenshot " + file);
        } finally {
            // shouldCloseApp defaults to true, so ending the session also closes the app window.
            step("Close app and end session");
            driver.quit();
            driver = null;
        }
    }

    // On HyperExecute Appium is started as a background service, so it may still be booting
    // when the first test runs.
    private static void waitForAppium(String appiumUrl) {
        HttpClient http = HttpClient.newHttpClient();
        HttpRequest status = HttpRequest.newBuilder(URI.create(appiumUrl + "/status")).timeout(Duration.ofSeconds(2)).build();
        long deadline = System.nanoTime() + Duration.ofSeconds(90).toNanos();
        while (System.nanoTime() < deadline) {
            try {
                if (http.send(status, HttpResponse.BodyHandlers.discarding()).statusCode() == 200) {
                    return;
                }
            } catch (IOException e) {
                // Not listening yet.
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        throw new IllegalStateException("Appium is not reachable at " + appiumUrl);
    }

    private Properties loadInstalledApp() throws IOException {
        Properties props = new Properties();
        Path env = Paths.get("build", installedAppEnv());
        if (Files.exists(env)) {
            try (var reader = Files.newBufferedReader(env)) {
                props.load(reader);
            }
        }
        String fromEnv = System.getenv("APP_ID");
        if (fromEnv != null && !fromEnv.isBlank()) {
            props.setProperty("APP_ID", fromEnv);
        }
        if (props.getProperty("APP_ID") == null) {
            throw new IllegalStateException(
                    "No installed app found. Run scripts/install-msix.ps1 <msix|zip|url> first, or set APP_ID.");
        }
        return props;
    }
}
