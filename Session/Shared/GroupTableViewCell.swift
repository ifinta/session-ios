//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import UIKit
import SignalUtilitiesKit

@objc class GroupTableViewCell: UITableViewCell {

    // MARK: -

//    private let avatarView = AvatarImageView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()

    init() {
        super.init(style: .default, reuseIdentifier: GroupTableViewCell.logTag())

        // Font config
        nameLabel.font = .ows_dynamicTypeBody
        nameLabel.textColor = Theme.primaryColor
        subtitleLabel.font = UIFont.ows_regularFont(withSize: 11.0)
        subtitleLabel.textColor = Theme.secondaryColor

        // Layout

//        avatarView.autoSetDimension(.width, toSize: CGFloat(kStandardAvatarSize))
//        avatarView.autoPinToSquareAspectRatio()

        let textRows = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        textRows.axis = .vertical
        textRows.alignment = .leading

        let columns = UIStackView(arrangedSubviews: [ textRows ])
        columns.axis = .horizontal
        columns.alignment = .center
        columns.spacing = kContactCellAvatarTextMargin

        self.contentView.addSubview(columns)
        columns.autoPinEdgesToSuperviewMargins()
    }

    required init?(coder aDecoder: NSCoder) {
        notImplemented()
    }

    @objc
    public func configure(thread: TSGroupThread) {
        OWSTableItem.configureCell(self)

        if let groupName = thread.groupModel.groupName, !groupName.isEmpty {
            self.nameLabel.text = groupName
        } else {
            self.nameLabel.text = MessageStrings.newGroupDefaultTitle
        }

        let groupMemberIds: [String] = thread.groupModel.groupMemberIds
        let groupMemberNames = groupMemberIds.map { (recipientId: String) in
            SSKEnvironment.shared.profileManager.profileNameForRecipient(withID: recipientId, avoidingWriteTransaction: true)!
        }.joined(separator: ", ")
        self.subtitleLabel.text = groupMemberNames

//        self.avatarView.image = OWSAvatarBuilder.buildImage(thread: thread, diameter: kStandardAvatarSize)
    }

}
