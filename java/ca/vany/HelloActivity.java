package ca.vany;

public class HelloActivity extends android.app.Activity {
  @Override
  public void onCreate(android.os.Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    android.widget.LinearLayout layout = new android.widget.LinearLayout(this);

    layout.setOrientation(layout.VERTICAL);
    
    android.widget.TextView textView = new android.widget.TextView(this);
    textView.setText("Hello World");

    layout.addView(textView);
    
    setContentView(layout);
  }
}
