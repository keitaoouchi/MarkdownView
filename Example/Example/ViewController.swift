import UIKit

final class ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    let stackView = UIStackView()
    stackView.axis = .vertical

    let btn1 = UIButton()
    btn1.setTitle("Code Only Example", for: .normal)
    btn1.addTarget(self, action: #selector(openCodeOnlySample(sender:)), for: .touchUpInside)

    let btn2 = UIButton()
    btn2.setTitle("Storyboard Example", for: .normal)
    btn2.addTarget(self, action: #selector(openStoryboardSample(sender:)), for: .touchUpInside)

    let btn3 = UIButton()
    btn3.setTitle("ScrollView Example", for: .normal)
    btn3.addTarget(self, action: #selector(openScrollViewSample(sender:)), for: .touchUpInside)
    
    let btn4 = UIButton()
    btn4.setTitle("Custom CSS", for: .normal)
    btn4.addTarget(self, action: #selector(openExample5), for: .touchUpInside)
    
    let btn5 = UIButton()
    btn5.setTitle("Add Plugin", for: .normal)
    btn5.addTarget(self, action: #selector(openExample6), for: .touchUpInside)

    [
      btn1,
      btn2,
      btn3,
      btn4,
      btn5
    ].forEach { button in

      button.setTitleColor(UIColor.systemBlue, for: .normal)
      button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
      button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
      stackView.addArrangedSubview(button)

    }

    view.addSubview(stackView)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
  }

  @objc func openCodeOnlySample(sender: Any) {
    let example = CodeOnlySampleViewController()
    navigationController?.pushViewController(example, animated: true)
  }

  @objc func openStoryboardSample(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "StoryboardSampleViewController") as! StoryboardSampleViewController
    navigationController?.pushViewController(example, animated: true)
  }

  @objc func openScrollViewSample(sender: Any) {
    let example = storyboard?.instantiateViewController(
      withIdentifier: "ScrollViewSampleViewController") as! ScrollViewSampleViewController
    navigationController?.pushViewController(example, animated: true)
  }
  
  @objc func openExample5(sender: Any) {
    let example = CustomCssSampleViewController()
    navigationController?.pushViewController(example, animated: true)
  }
  
  @objc func openExample6(sender: Any) {
    let example = PluginsSampleViewController()
    navigationController?.pushViewController(example, animated: true)
  }
}
