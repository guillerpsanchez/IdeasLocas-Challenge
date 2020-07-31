//
//  ChatTableViewCell.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 27/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import SDWebImage

class ChatTableViewCell: UITableViewCell {

    static let identifier = "ChatTableViewCell"

    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 50
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        userImageView.frame = CGRect(x: 10, y: 10, width: 100, height: 100)

        userNameLabel.frame = CGRect(x: userImageView.right + 10, y: 10, width: contentView.width - 20 - userImageView.width, height: (contentView.height-20)/2 )

    }

    public func configure(with model: Chat) {
        userNameLabel.text = model.name

        let path = "images/\(model.otherUserEmail)_profile_picture.png"
        ManageStorage.shared.downloadURL(for: path, completion: { [weak self] result in
            switch result {
            case .success(let url):

                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url, completed: nil)
                }

            case .failure(_):
                break
            }
        })
    }

}
