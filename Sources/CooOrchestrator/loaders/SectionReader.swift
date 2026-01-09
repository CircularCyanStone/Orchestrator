// Copyright © 2025 Coo. All rights reserved.
// 文件功能描述：封装 Mach-O Section 读取的底层通用逻辑。
// 类型功能描述：提供泛型方法 `read<T>`，从所有加载的 Image 中读取指定 Section 的数据。

import Foundation
import MachO

/// 封装 Mach-O 读取逻辑的辅助类型
/// - 职责：遍历所有 Mach-O Image，定位指定 Section，并将其内存映射为 Swift 类型数组。
enum SectionReader {
    
    /// 从指定的 Mach-O Section 读取连续的 T 类型元素数组
    ///
    /// - Parameters:
    ///   - type: 读取的元素类型 (通常是结构体或 StaticString)
    ///   - segment: Segment 名称，默认为 "__DATA"。在 Mach-O 中，可读写的数据通常放在 __DATA 段。
    ///   - section: Section 名称，即我们需要查找的具体节。
    /// - Returns: 读取到的元素数组
    static func read<T>(
        _ type: T.Type,
        segment: String = "__DATA",
        section: String
    ) -> [T] {
        // _dyld_image_count(): 获取当前进程加载的 Mach-O Image (二进制镜像) 总数。
        // 一个 App 运行时包含：主程序的可执行文件 + 链接的各种动态库 (System Frameworks, Embedded Frameworks 等)。
        // 每一个都是一个 Image。
        let imageCount = _dyld_image_count()
        var infos: [T] = []
        
        // 缓存主 Bundle 路径，用于过滤。
        // 我们通常只关心自己 App 内的代码（主程序 + 嵌入的 Framework），不关心系统的库（如 UIKit）。
        let mainBundlePath = Bundle.main.bundlePath
        
        // 遍历所有加载的 Mach-O Image
        for i in 0..<imageCount {
            // 1. 获取 Image 名称 (路径)
            // _dyld_get_image_name(i) 返回的是一个 C 字符串 (UnsafePointer<CChar>)
            guard let namePtr = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: namePtr)
            
            // 过滤：只扫描主 Bundle 及其包含的库，提升扫描效率并避免读取系统库导致的潜在问题
            guard imageName.hasPrefix(mainBundlePath) else { continue }
            
            // 2. 获取 Image Header
            // _dyld_get_image_header(i) 返回指向该 Image 头部信息的指针
            guard let header = _dyld_get_image_header(i) else { continue }
            
            // 校验 Magic Number：确认这是一个 64 位的 Mach-O 文件
            // header.pointee 访问指针指向的具体结构体内容
            guard header.pointee.magic == MH_MAGIC_64 else { continue }
            
            // **Swift 指针转换技巧 1: assumingMemoryBound**
            // `header` 是 `UnsafePointer<mach_header>` 类型 (C 结构体)。
            // 但我们需要把它当做 `mach_header_64` 来处理。
            // `UnsafeRawPointer(header)`: 先转为“生指针”（无类型指针，类似 void*）。
            // `.assumingMemoryBound(to: mach_header_64.self)`: 告诉编译器，“我非常确定这段内存里放的就是 mach_header_64，请把它当做这个类型处理”。
            // 注意：这只是为了让编译器允许我们访问 mach_header_64 的字段，并不会移动内存数据。
            let machHeader = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
            
            // 3. 获取 Section 数据指针
            // getsectiondata 是 <mach-o/getsect.h> 提供的 C 函数。
            // 作用：在给定的 mach_header 中，查找指定 segment 和 section 的位置。
            // 返回值：指向该 Section 数据起始位置的指针 (如果是 ASLR 开启的，它会自动加上 slide 偏移，非常方便)。
            var size: UInt = 0
            guard let sectionStart = getsectiondata(
                machHeader,
                segment,
                section,
                &size // 传入变量地址，函数执行完后会把 section 的大小写入这个变量
            ) else { continue }
            
            // 4. 读取数据并转换为 Swift 数组
            if let buffer = getInfoBuffer(from: UnsafeRawPointer(sectionStart), sectionSize: Int(size), type: T.self) {
                infos.append(contentsOf: buffer)
            }
        }
        
        return infos
    }
    
    /// 将内存区域转换为 Swift 的 Buffer (类似数组视图)
    ///
    /// - Parameters:
    ///   - sectionStart: Section 数据的起始内存地址 (无类型指针)
    ///   - sectionSize: Section 数据的总字节大小
    ///   - type: 我们期望将这段内存解读为什么类型
    private static func getInfoBuffer<InfoType>(
        from sectionStart: UnsafeRawPointer,
        sectionSize: Int,
        type: InfoType.Type
    ) -> UnsafeBufferPointer<InfoType>? {
        guard sectionSize > 0 else { return nil }
        
        // 获取目标类型 T 的大小 (字节数) 和对齐步长
        let typeSize = MemoryLayout<InfoType>.size
        let typeStride = MemoryLayout<InfoType>.stride
        
        // 计算这段内存里包含了多少个 T 类型的元素
        // 正常情况下 count = sectionSize / typeStride
        let count: Int
        if sectionSize == typeSize {
            count = 1
        } else {
            // 这里处理可能存在的 padding 逻辑，通常直接除以 stride 即可
            count = 1 + (sectionSize - typeSize) / typeStride
        }
        
        // **Swift 指针转换技巧 2: bindMemory**
        // `sectionStart` 是 UnsafeRawPointer (void*)。
        // 我们要读取它里面的数据作为 `InfoType` 类型。
        // `bindMemory(to:capacity:)`: 这是一个这一步很关键的操作。
        // 它向编译器声明：“从现在开始，请把这块内存看作是 InfoType 类型”。
        // 返回值是一个 `UnsafePointer<InfoType>` (Typed Pointer)。
        let ptr = sectionStart.bindMemory(to: InfoType.self, capacity: count)
        
        // **Swift 指针转换技巧 3: UnsafeBufferPointer**
        // 有了类型化的指针 `ptr` 和数量 `count`，我们就可以创建一个 BufferPointer。
        // UnsafeBufferPointer 遵循 Swift 的 Collection 协议（即它像一个数组一样可以被遍历、map、filter）。
        // 这一步没有发生内存拷贝，它只是给这块裸内存加上了一个“数组的外壳/视图”。
        return UnsafeBufferPointer(start: ptr, count: count)
    }
}
