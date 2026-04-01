import SwiftUI
import PhotosUI

struct ProfilePhotoGrid: View {
    let photoUrls: [String]
    let maxPhotos: Int
    var onAdd: ((Data) -> Void)?
    var onRemove: ((String) -> Void)?

    @State private var selectedItem: PhotosPickerItem?

    private let columnCount = 3

    var body: some View {
        let photoEntries = Array(photoUrls.enumerated())
        let rowCount = max((photoEntries.count + (photoUrls.count < maxPhotos ? 1 : 0) + columnCount - 1) / columnCount, 1)

        VStack(spacing: 8) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        let itemIndex = rowIndex * columnCount + columnIndex

                        if itemIndex < photoEntries.count {
                            let entry = photoEntries[itemIndex]
                            photoCell(url: entry.element)
                        } else if itemIndex == photoEntries.count && photoUrls.count < maxPhotos {
                            addPhotoCell
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                        }
                    }
                }
            }
        }
    }

    private func photoCell(url: String) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(HarvestTheme.Colors.divider)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .overlay {
                        ProgressView()
                    }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, maxHeight: 150)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))

            if onRemove != nil {
                Button {
                    onRemove?(url)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.45))
                        )
                        .shadow(radius: 2)
                }
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .padding(8)
                .buttonStyle(.plain)
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
        .clipShape(RoundedRectangle(cornerRadius: HarvestTheme.Radius.md))
    }

    private var addPhotoCell: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(Color(.secondarySystemBackground))
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                        .stroke(Color(.separator), lineWidth: 1)
                }
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(HarvestTheme.Colors.primary)
                        Text("Add")
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(.primary)
                    }
                }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    onAdd?(data)
                }
                selectedItem = nil
            }
        }
    }
}
