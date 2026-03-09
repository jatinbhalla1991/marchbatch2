public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
        System.out.println("Welcome to jatin!");
        
        // Display system information
        System.out.println("Java Version: " + System.getProperty("java.version"));
        System.out.println("Operating System: " + System.getProperty("os.name"));
        
        // Simple calculation example
        int sum = calculateSum(10, 20);
        System.out.println("Sum of 10 and 20 is: " + sum);
    }
    
    public static int calculateSum(int a, int b) {
        return a + b;
    }
}
