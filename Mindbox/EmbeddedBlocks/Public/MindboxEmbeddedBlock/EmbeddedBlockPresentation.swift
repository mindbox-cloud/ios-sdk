//
//  EmbeddedBlockPresentation.swift
//  Mindbox
//
//  Created by vailence on 10.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import CoreGraphics

/// Что контейнер показывает прямо сейчас — снимок для SwiftUI-обёртки.
///
/// UIKit-хосту такой тип не нужен: контейнер сам заявляет высоту через `intrinsicContentSize` и сам
/// держит внутри нужный слой. SwiftUI не умеет ни того, ни другого. Высоту представимой вью
/// назначает обёртка, а плейсхолдер и экран ошибки хоста — это SwiftUI-вью, и рисовать их обязана
/// тоже она: вью, отданная контейнеру через отдельный `UIHostingController`, выпадает из дерева
/// SwiftUI и теряет его окружение. Поэтому обёртке нужен не только размер, но и текущий слой.
///
/// Deliberately internal, как и `EmbeddedBlockState`: хост знает только исход, а не то, как
/// контейнер к нему пришёл.
struct EmbeddedBlockPresentation: Equatable {

    /// Слой, видимый в контейнере.
    enum Layer {

        /// Идёт загрузка: показан плейсхолдер — хоста или дефолтный шиммер SDK.
        case placeholder

        /// Показано содержимое блока.
        case content

        /// Показан экран ошибки, на который хост согласился явно.
        case errorView

        /// Блок схлопнут: провал без экрана ошибки или пустой блок.
        case nothing
    }

    let layer: Layer

    /// Высота, которую контейнер занимает с этим слоем.
    let height: CGFloat
}
