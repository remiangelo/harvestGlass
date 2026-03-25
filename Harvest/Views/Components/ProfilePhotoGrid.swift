import SwiftUI
import PhotosUI

struct ProfilePhotoGrid: View {
    let photoUrls: [String]
    let maxPhotos: Int
    var onAdd: ((Data) -> Void)?
    var onRemove: ((Int) -> Void)?

    @State private var selectedItem: PhotosPickerItem?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(photoUrls.enumerated()), id: \.offset) { index, url in
                photoCell(url: url, index: index)
            }

            if photoUrls.count < maxPhotos {
                addPhotoCell
            }
        }
    }

    private func photoCell(url: String, index: Int) -> some View {
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
                    onRemove?(index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(HarvestTheme.Colors.textOnBlack)
                        .shadow(radius: 2)
                }
                .padding(4)
            }
        }
    }

    private var addPhotoCell: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                .fill(Color.white)
                .frame(height: 150)
                .overlay {
                    RoundedRectangle(cornerRadius: HarvestTheme.Radius.md)
                        .stroke(HarvestTheme.Colors.deepPlum.opacity(0.12), lineWidth: 1)
                }
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(HarvestTheme.Colors.primary)
                        Text("Add")
                            .font(HarvestTheme.Typography.caption)
                            .foregroundStyle(HarvestTheme.Colors.textOnCream)
                    }
                }
        }
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
