/**
 * Minimal point-of-sale screen used as the app under test.
 * Every interactive element has a testID, which React Native for Windows
 * exposes as the UI Automation AutomationId (Appium: accessibility id).
 */
import React, {useState} from 'react';
import {Pressable, ScrollView, StyleSheet, Text, TextInput, View} from 'react-native';

type Product = {id: string; name: string; price: number};

const PRODUCTS: Product[] = [
  {id: 'coffee', name: 'Coffee', price: 3.5},
  {id: 'bagel', name: 'Bagel', price: 2.25},
  {id: 'juice', name: 'Orange Juice', price: 4.0},
];

const TAX_RATE = 0.08;
const money = (n: number) => `$${n.toFixed(2)}`;

function Button({testID, label, onPress, disabled}: {testID: string; label: string; onPress: () => void; disabled?: boolean}) {
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={label}
      disabled={disabled}
      onPress={onPress}
      style={({pressed}) => [styles.button, disabled && styles.buttonDisabled, pressed && styles.buttonPressed]}>
      <Text style={styles.buttonText}>{label}</Text>
    </Pressable>
  );
}

export default function App() {
  const [cart, setCart] = useState<Record<string, number>>({});
  const [customer, setCustomer] = useState('');
  const [receipt, setReceipt] = useState<string | null>(null);
  const [orderNo, setOrderNo] = useState(1001);

  const items = PRODUCTS.filter(p => cart[p.id]);
  const count = items.reduce((n, p) => n + cart[p.id], 0);
  const subtotal = items.reduce((s, p) => s + p.price * cart[p.id], 0);
  const tax = Math.round(subtotal * TAX_RATE * 100) / 100;
  const total = subtotal + tax;

  const add = (id: string) => {
    setReceipt(null);
    setCart(c => ({...c, [id]: (c[id] ?? 0) + 1}));
  };
  const clear = () => {
    setCart({});
    setReceipt(null);
  };
  const checkout = () => {
    const name = customer.trim() || 'Walk-in';
    setReceipt(`Order #${orderNo} placed for ${name}: ${money(total)}`);
    setOrderNo(n => n + 1);
    setCart({});
    setCustomer('');
  };

  return (
    <ScrollView contentContainerStyle={styles.screen}>
      <Text testID="title" style={styles.title}>POS Sample</Text>

      <Text style={styles.heading}>Products</Text>
      {PRODUCTS.map(p => (
        <View key={p.id} style={styles.row}>
          <Text testID={`product-${p.id}`} style={styles.cell}>{`${p.name} ${money(p.price)}`}</Text>
          <Button testID={`add-${p.id}`} label={`Add ${p.name}`} onPress={() => add(p.id)} />
        </View>
      ))}

      <Text style={styles.heading}>Cart</Text>
      {items.length === 0 ? (
        <Text testID="cart-empty" style={styles.muted}>Cart is empty</Text>
      ) : (
        items.map(p => (
          <Text key={p.id} testID={`cart-line-${p.id}`} style={styles.cell}>
            {`${cart[p.id]} x ${p.name} = ${money(p.price * cart[p.id])}`}
          </Text>
        ))
      )}
      <Text testID="cart-count" style={styles.cell}>{`Items: ${count}`}</Text>
      <Text testID="subtotal" style={styles.cell}>{`Subtotal: ${money(subtotal)}`}</Text>
      <Text testID="tax" style={styles.cell}>{`Tax: ${money(tax)}`}</Text>
      <Text testID="total" style={styles.total}>{`Total: ${money(total)}`}</Text>

      <TextInput
        testID="customer-name"
        accessibilityLabel="Customer name"
        placeholder="Customer name (optional)"
        value={customer}
        onChangeText={setCustomer}
        style={styles.input}
      />

      <View style={styles.row}>
        <Button testID="checkout" label="Checkout" onPress={checkout} disabled={count === 0} />
        <Button testID="clear-cart" label="Clear cart" onPress={clear} />
      </View>

      {receipt && <Text testID="receipt" style={styles.receipt}>{receipt}</Text>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {padding: 24, gap: 8},
  title: {fontSize: 28, fontWeight: '600'},
  heading: {fontSize: 18, fontWeight: '600', marginTop: 12},
  row: {flexDirection: 'row', alignItems: 'center', gap: 12},
  cell: {fontSize: 16, minWidth: 200},
  muted: {fontSize: 16, color: '#666'},
  total: {fontSize: 20, fontWeight: '700'},
  input: {borderWidth: 1, borderColor: '#999', borderRadius: 4, padding: 8, fontSize: 16, maxWidth: 360},
  button: {backgroundColor: '#0b5cad', paddingVertical: 8, paddingHorizontal: 14, borderRadius: 4},
  buttonDisabled: {backgroundColor: '#9bb5d0'},
  buttonPressed: {backgroundColor: '#084a8c'},
  buttonText: {color: 'white', fontSize: 15},
  receipt: {fontSize: 16, marginTop: 12, color: '#1a7f37', fontWeight: '600'},
});
