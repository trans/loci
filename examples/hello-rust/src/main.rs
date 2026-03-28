struct Greeter {
    name: String,
}

impl Greeter {
    fn new(name: &str) -> Self {
        Greeter {
            name: name.to_string(),
        }
    }

    fn greet(&self) -> String {
        format!("Hello, {}!", self.name)
    }
}

fn add(a: i32, b: i32) -> i32 {
    a + b
}

fn main() {
    let greeter = Greeter::new("world");
    println!("{}", greeter.greet());
    println!("2 + 3 = {}", add(2, 3));
}
