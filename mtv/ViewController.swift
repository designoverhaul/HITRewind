import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBarController()
    }
    
    private func setupTabBarController() {
        // Create the tab bar controller
        let tabBarController = UITabBarController()
        
        // Create Music Videos tab (your existing screen)
        let musicVideosController = PlayListViewController()
        musicVideosController.tabBarItem = UITabBarItem(
            title: "Music Videos",
            image: UIImage(systemName: "play.rectangle.fill"),
            tag: 0
        )
        
        // Create Live Shows tab (new Category-based screen)
        let liveShowsController = LiveShowsTabViewController()
        liveShowsController.tabBarItem = UITabBarItem(
            title: "Live Shows", 
            image: UIImage(systemName: "music.mic"),
            tag: 1
        )
        
        // Add controllers to tab bar
        tabBarController.viewControllers = [musicVideosController, liveShowsController]
        
        // Set up the tab bar appearance for tvOS
        tabBarController.tabBar.isTranslucent = true
        tabBarController.tabBar.barTintColor = UIColor.black.withAlphaComponent(0.8)
        tabBarController.tabBar.tintColor = UIColor.white
        
        // Add as child view controller
        addChild(tabBarController)
        tabBarController.view.frame = view.bounds
        view.addSubview(tabBarController.view)
        tabBarController.didMove(toParent: self)
    }
}

// MARK: - Live Shows Controller with Category Grid
class LiveShowsTabViewController: UIViewController {
    
    // MARK: - Properties
    private var categories: [Category] = []
    private var categoryTableView: UITableView!
    private var categoryCollectionView: UICollectionView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var purchaseButton: UIButton!
    private var selectedCategoryIndex: Int?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showLoadingIndicator()
        fetchCategories()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // MTV logo imageView setup (same as Music Videos)
        let imageView = UIImageView(image: UIImage(named: "logoVector"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // Purchase button (keeping same design pattern)
        purchaseButton = UIButton(type: .custom)
        purchaseButton.setTitle("🎵 Live Shows", for: .normal)
        purchaseButton.setTitleColor(.white, for: .normal)
        purchaseButton.backgroundColor = .clear
        purchaseButton.isUserInteractionEnabled = false // Just a label for now
        
        if let font = UIFont(name: "Inter", size: 25) {
            let fontDescriptor = font.fontDescriptor.withSymbolicTraits(.traitBold)
            if let boldFontDescriptor = fontDescriptor {
                purchaseButton.titleLabel?.font = UIFont(descriptor: boldFontDescriptor, size: 28)
            } else {
                purchaseButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
            }
        } else {
            purchaseButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        }
        
        if #available(tvOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
            configuration.titleAlignment = .leading
            purchaseButton.configuration = configuration
        } else {
            purchaseButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            purchaseButton.contentHorizontalAlignment = .left
        }
        
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(purchaseButton)
        
        // Category sidebar tableView setup (same structure as playlist sidebar)
        categoryTableView = UITableView()
        categoryTableView.dataSource = self
        categoryTableView.delegate = self
        categoryTableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        categoryTableView.backgroundColor = .clear
        // separatorStyle is not available on tvOS - remove this line
        view.addSubview(categoryTableView)
        categoryTableView.cellLayoutMarginsFollowReadableWidth = false
        categoryTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Two-column collection view for category banner images
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 40
        layout.minimumLineSpacing = 40
        layout.itemSize = CGSize(width: 495, height: 204) // Two columns: (990+40)/2 = 495 width each
        
        categoryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.dataSource = self
        categoryCollectionView.delegate = self
        categoryCollectionView.register(CategoryBannerCell.self, forCellWithReuseIdentifier: "CategoryBannerCell")
        view.addSubview(categoryCollectionView)
        categoryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Layout constraints (same pattern as Music Videos)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 112),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 66),
            imageView.widthAnchor.constraint(equalToConstant: 145),
            imageView.heightAnchor.constraint(equalToConstant: 115),
            
            purchaseButton.heightAnchor.constraint(equalToConstant: 50),
            purchaseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 51),
            purchaseButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            
            categoryTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -51),
            categoryTableView.topAnchor.constraint(equalTo: purchaseButton.bottomAnchor, constant: 30),
            categoryTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            categoryTableView.widthAnchor.constraint(equalToConstant: 400),
            
            categoryCollectionView.leadingAnchor.constraint(equalTo: categoryTableView.trailingAnchor, constant: 70),
            categoryCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            categoryCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            categoryCollectionView.bottomAnchor.constraint(equalTo: categoryTableView.bottomAnchor)
        ])
    }
    
    // MARK: - Data Fetching
    private func fetchCategories() {
        sortAndArrangeCategories { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let categories):
                self.categories = categories
                DispatchQueue.main.async {
                    self.categoryTableView.reloadData()
                    self.categoryCollectionView.reloadData()
                    self.hideLoadingIndicator()
                    
                    if !self.categories.isEmpty {
                        // Auto-select the first category
                        self.selectedCategoryIndex = 0
                        let indexPath = IndexPath(row: 0, section: 0)
                        self.categoryTableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                    }
                }
            case .failure(let error):
                print("Error fetching categories: \(error)")
                self.hideLoadingIndicator()
            }
        }
    }
    
    // MARK: - Loading Indicator
    private func showLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
    }
}

// MARK: - TableView DataSource & Delegate (Sidebar)
extension LiveShowsTabViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        let category = categories[indexPath.row]
        
        cell.textLabel?.text = category.fields.categoryName
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        // Custom selection background
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(hex: "#A789FD")
        cell.selectedBackgroundView = backgroundView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedCategoryIndex = indexPath.row
        categoryCollectionView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - CollectionView DataSource & Delegate (Two-Column Grid)
extension LiveShowsTabViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count // Show all categories as banners
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryBannerCell", for: indexPath) as! CategoryBannerCell
        let category = categories[indexPath.item]
        cell.configure(with: category)
        return cell
    }
}

// MARK: - Category Banner Cell
class CategoryBannerCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.layer.cornerRadius = 15
        contentView.clipsToBounds = true
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        titleLabel.layer.cornerRadius = 8
        titleLabel.clipsToBounds = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            titleLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(with category: Category) {
        titleLabel.text = category.fields.categoryName
        
        // Load category image from Airtable
        if let attachments = category.fields.categoryImage,
           let firstAttachment = attachments.first,
           let imageURL = URL(string: firstAttachment.url) {
            
            URLSession.shared.dataTask(with: imageURL) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.imageView.image = image
                    }
                }
            }.resume()
        } else {
            // Fallback gradient background
            imageView.image = nil
            imageView.backgroundColor = UIColor(hex: category.fields.color ?? "#6640C6")
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.layer.shadowColor = UIColor.white.cgColor
                self.layer.shadowOffset = CGSize(width: 0, height: 0)
                self.layer.shadowOpacity = 0.8
                self.layer.shadowRadius = 10
            } else {
                self.transform = .identity
                self.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}

// MARK: - Category Model & API Functions
struct Category {
    let id: String
    let fields: CategoryFields
}

struct CategoryFields {
    let categoryName: String
    let categoryImage: [CategoryAttachment]?
    let color: String?
}

struct CategoryAttachment {
    let id: String
    let url: String
    let filename: String
}

// Function to fetch and arrange categories from Airtable
func sortAndArrangeCategories(completion: @escaping (Result<[Category], Error>) -> Void) {
    guard let url = URL(string: "https://api.airtable.com/v0/appxCBIOkiJEZiph7/Category") else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
            return
        }
        
        do {
            let airtableResponse = try JSONDecoder().decode(CategoryAirtableResponse.self, from: data)
            let categories = airtableResponse.records.map { record in
                Category(
                    id: record.id,
                    fields: CategoryFields(
                        categoryName: record.fields.categoryName ?? "Unknown Category",
                        categoryImage: record.fields.categoryImage?.map { attachment in
                            CategoryAttachment(
                                id: attachment.id,
                                url: attachment.url,
                                filename: attachment.filename
                            )
                        },
                        color: record.fields.color
                    )
                )
            }
            completion(.success(categories))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}

// MARK: - Airtable Response Models
struct CategoryAirtableResponse: Codable {
    let records: [CategoryRecord]
}

struct CategoryRecord: Codable {
    let id: String
    let fields: CategoryRecordFields
}

struct CategoryRecordFields: Codable {
    let categoryName: String?
    let categoryImage: [CategoryAttachmentRecord]?
    let color: String?
    
    enum CodingKeys: String, CodingKey {
        case categoryName = "CategoryName"
        case categoryImage = "CategoryImage"
        case color = "Color"
    }
}

struct CategoryAttachmentRecord: Codable {
    let id: String
    let url: String
    let filename: String
}



