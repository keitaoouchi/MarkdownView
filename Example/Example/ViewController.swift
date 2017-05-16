import UIKit

final class ViewController: UIViewController {


  override func viewDidLoad() {
    super.viewDidLoad()

    let stackView = UIStackView()
    stackView.axis = .vertical

    let example1Button = UIButton()
    example1Button.setTitle("Code Only Example", for: .normal)
    example1Button.addTarget(self, action: #selector(openExample1), for: .touchUpInside)

    let example2Button = UIButton()
    example2Button.setTitle("Storyboard Example", for: .normal)
    example2Button.addTarget(self, action: #selector(openExample2), for: .touchUpInside)

    let example3Button = UIButton()
    example3Button.setTitle("ScrollView Example", for: .normal)
    example3Button.addTarget(self, action: #selector(openExample3), for: .touchUpInside)

    [
      example1Button,
      example2Button,
      example3Button
    ].forEach { button in

      button.setTitleColor(UIColor.blue, for: .normal)
      button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
      button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
      stackView.addArrangedSubview(button)

    }

    view.addSubview(stackView)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
  }

  func openExample1(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "Example1") as! Example1ViewController
    navigationController?.pushViewController(example, animated: true)
  }

  func openExample2(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "Example2") as! Example2ViewController
    navigationController?.pushViewController(example, animated: true)
  }

  func openExample3(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "Example3") as! Example3ViewController
    navigationController?.pushViewController(example, animated: true)
  }
}
