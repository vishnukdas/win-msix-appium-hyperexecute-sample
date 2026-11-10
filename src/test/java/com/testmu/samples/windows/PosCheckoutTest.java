package com.testmu.samples.windows;

import org.testng.annotations.Test;

import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertTrue;

/** Launch → validate → close flows against the React Native for Windows POS sample (pos-app/). */
public class PosCheckoutTest extends BaseWindowsTest {

    @Override
    protected void waitUntilReady() {
        // The JS bundle renders after the window appears; wait for the first real control.
        byId("title");
    }

    @Test
    public void launchesWithEmptyCart() {
        assertText("title", "POS Sample");
        assertText("product-coffee", "Coffee $3.50");
        assertTrue(byId("cart-empty").isDisplayed(), "Empty-cart message shown");
        assertText("total", "Total: $0.00");
        assertFalse(byId("checkout").isEnabled(), "Checkout disabled for an empty cart");
        step("Checkout is disabled while the cart is empty");
    }

    @Test
    public void addingItemsUpdatesTotals() {
        click("add-coffee");
        click("add-coffee");
        click("add-bagel");
        assertText("cart-line-coffee", "2 x Coffee = $7.00");
        assertText("cart-line-bagel", "1 x Bagel = $2.25");
        assertText("cart-count", "Items: 3");
        assertText("subtotal", "Subtotal: $9.25");
        assertText("tax", "Tax: $0.74");
        assertText("total", "Total: $9.99");
    }

    @Test
    public void checkoutShowsReceiptAndResetsCart() {
        click("add-juice");
        assertText("total", "Total: $4.32");
        typeInto("customer-name", "Alex");
        click("checkout");
        assertText("receipt", "Order #1001 placed for Alex: $4.32");
        assertText("cart-count", "Items: 0");
        assertTrue(byId("cart-empty").isDisplayed(), "Cart emptied after checkout");
    }

    @Test
    public void clearCartRemovesAllItems() {
        click("add-coffee");
        click("add-juice");
        assertText("cart-count", "Items: 2");
        click("clear-cart");
        assertText("cart-count", "Items: 0");
        assertText("total", "Total: $0.00");
    }
}
