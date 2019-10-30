//
//  StringFile.swift
//  dswift
//
//  Created by Tyler Anger on 2019-08-11.
//

import Foundation

public struct StringFile {
    private let path: String
    private var content: String = ""
    private var encoding: String.Encoding = .utf8
    
    /// A Boolean value indicating whether a string has no characters.
    public var isEmpty: Bool { return self.content.isEmpty }
    /// The number of characters in a string.
    public var count: Int { return self.content.count }
    /// The position of the first character in a nonempty string.
    ///
    /// In an empty string, `startIndex` is equal to `endIndex`.
    public var startIndex: String.Index { return self.content.startIndex }
    /// A string's "past the end" position---that is, the position one greater
    /// than the last valid subscript argument.
    ///
    /// In an empty string, `endIndex` is equal to `startIndex`.
    public var endIndex: String.Index { return self.content.endIndex }
    /// The first element of the collection.
    ///
    /// If the collection is empty, the value of this property is `nil`.
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     if let firstNumber = numbers.first {
    ///         print(firstNumber)
    ///     }
    ///     // Prints "10"
    public var first: Character? { return self.content.first }
    /// The last element of the collection.
    ///
    /// If the collection is empty, the value of this property is `nil`.
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     if let lastNumber = numbers.last {
    ///         print(lastNumber)
    ///     }
    ///     // Prints "50"
    ///
    /// - Complexity: O(1)
    public var last: Character? { return self.content.last }
    
    public subscript(r: Range<String.Index>) -> Substring { return self.content[r] }
    public subscript(i: String.Index) -> Character { return self.content[i] }
    
    public init(_ path: String) throws {
        let pth = NSString(string: path).expandingTildeInPath
        self.path = pth
        if FileManager.default.fileExists(atPath: pth) {
            self.content = try String(contentsOfFile: pth, foundEncoding: &self.encoding)
            //self.content = try String(contentsOfFile: pth, encoding: .utf8)
            //self.encoding = self.content.fastestEncoding
        }
    }
    
    public func save() throws {
        try self.content.write(toFile: self.path, atomically: true, encoding: self.encoding)
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    ///
    /// - Parameter element: The element to find in the sequence.
    /// - Returns: true if the element was found in the sequence; otherwise, false.
    public func contains<S>(_ element: S) -> Bool where S: StringProtocol {
        return self.content.contains(element)
    }
    
    /// Inserts a new character at the specified position.
    ///
    /// Calling this method invalidates any existing indices for use with this
    /// string.
    ///
    /// - Parameters:
    ///   - newElement: The new character to insert into the string.
    ///   - i: A valid index of the string. If `i` is equal to the string's end
    ///     index, this methods appends `newElement` to the string.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the string.
    public mutating func insert(_ newElement: Character, at i: String.Index) {
        self.content.insert(newElement, at: i)
    }
    /// Inserts a collection of characters at the specified position.
    ///
    /// Calling this method invalidates any existing indices for use with this
    /// string.
    ///
    /// - Parameters:
    ///   - newElements: A collection of `Character` elements to insert into the
    ///     string.
    ///   - i: A valid index of the string. If `i` is equal to the string's end
    ///     index, this methods appends the contents of `newElements` to the
    ///     string.
    ///
    /// - Complexity: O(*n*), where *n* is the combined length of the string and
    ///   `newElements`.
    public mutating func insert<S>(contentsOf newElements: S, at i: String.Index) where S : Collection, S.Element == Character {
        self.content.insert(contentsOf: newElements, at: i)
    }
    /// Replaces the specified subrange of elements with the given collection.
    ///
    /// This method has the effect of removing the specified range of elements
    /// from the collection and inserting the new elements at the same location.
    /// The number of new elements need not match the number of elements being
    /// removed.
    ///
    /// In this example, three elements in the middle of an array of integers are
    /// replaced by the five elements of a `Repeated<Int>` instance.
    ///
    ///      var nums = [10, 20, 30, 40, 50]
    ///      nums.replaceSubrange(1...3, with: repeatElement(1, count: 5))
    ///      print(nums)
    ///      // Prints "[10, 1, 1, 1, 1, 1, 50]"
    ///
    /// If you pass a zero-length range as the `subrange` parameter, this method
    /// inserts the elements of `newElements` at `subrange.startIndex`. Calling
    /// the `insert(contentsOf:at:)` method instead is preferred.
    ///
    /// Likewise, if you pass a zero-length collection as the `newElements`
    /// parameter, this method removes the elements in the given subrange
    /// without replacement. Calling the `removeSubrange(_:)` method instead is
    /// preferred.
    ///
    /// Calling this method may invalidate any existing indices for use with this
    /// collection.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the collection to replace. The bounds of
    ///     the range must be valid indices of the collection.
    ///   - newElements: The new elements to add to the collection.
    ///
    /// - Complexity: O(*n* + *m*), where *n* is length of this collection and
    ///   *m* is the length of `newElements`. If the call to this method simply
    ///   appends the contents of `newElements` to the collection, the complexity
    ///   is O(*m*).
    public mutating func replaceSubrange<C, R>(_ subrange: R,
                                               with newElements: C) where C : Collection, R : RangeExpression, String.Element == C.Element, String.Index == R.Bound {
        return self.content.replaceSubrange(subrange, with: newElements)
    }
    /// Replaces the text within the specified bounds with the given characters.
    ///
    /// Calling this method invalidates any existing indices for use with this
    /// string.
    ///
    /// - Parameters:
    ///   - bounds: The range of text to replace. The bounds of the range must be
    ///     valid indices of the string.
    ///   - newElements: The new characters to add to the string.
    ///
    /// - Complexity: O(*m*), where *m* is the combined length of the string and
    ///   `newElements`. If the call to `replaceSubrange(_:with:)` simply
    ///   removes text at the end of the string, the complexity is O(*n*), where
    ///   *n* is equal to `bounds.count`.
    public mutating func replaceSubrange<C>(_ bounds: Range<String.Index>, with newElements: C) where C : Collection, C.Element == Character {
        return self.content.replaceSubrange(bounds, with: newElements)
    }
    
    /// Replaces all occurences of a given text with other text
    public mutating func replaceOccurrences<Target, Replacement>(of target: Target,
                                                                 with replacement: Replacement,
                                                                 options: String.CompareOptions = [],
                                                                 range searchRange: Range<String.Index>? = nil) where Target : StringProtocol, Replacement : StringProtocol {
        self.content = self.content.replacingOccurrences(of: target,
                                                         with: replacement,
                                                         options: options,
                                                         range: searchRange)
    }
    
    /// Removes and returns the character at the specified position.
    ///
    /// All the elements following `i` are moved to close the gap. This example
    /// removes the hyphen from the middle of a string.
    ///
    ///     var nonempty = "non-empty"
    ///     if let i = nonempty.firstIndex(of: "-") {
    ///         nonempty.remove(at: i)
    ///     }
    ///     print(nonempty)
    ///     // Prints "nonempty"
    ///
    /// Calling this method invalidates any existing indices for use with this
    /// string.
    ///
    /// - Parameter i: The position of the character to remove. `i` must be a
    ///   valid index of the string that is not equal to the string's end index.
    /// - Returns: The character that was removed.
    public mutating func remove(at i: String.Index) -> Character {
        return self.content.remove(at: i)
    }
    /// Removes and returns the first element of the collection.
    ///
    /// The collection must not be empty.
    ///
    ///     var bugs = ["Aphid", "Bumblebee", "Cicada", "Damselfly", "Earwig"]
    ///     bugs.removeFirst()
    ///     print(bugs)
    ///     // Prints "["Bumblebee", "Cicada", "Damselfly", "Earwig"]"
    ///
    /// Calling this method may invalidate any existing indices for use with this
    /// collection.
    ///
    /// - Returns: The removed element.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    public mutating func removeFirst() -> Character {
        return self.content.removeFirst()
    }
    /// Removes the specified number of elements from the beginning of the
    /// collection.
    ///
    ///     var bugs = ["Aphid", "Bumblebee", "Cicada", "Damselfly", "Earwig"]
    ///     bugs.removeFirst(3)
    ///     print(bugs)
    ///     // Prints "["Damselfly", "Earwig"]"
    ///
    /// Calling this method may invalidate any existing indices for use with this
    /// collection.
    ///
    /// - Parameter k: The number of elements to remove from the collection.
    ///   `k` must be greater than or equal to zero and must not exceed the
    ///   number of elements in the collection.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    public mutating func removeFirst(_ k: Int) {
        self.content.removeFirst(k)
    }
    /// Removes and returns the last element of the collection.
    ///
    /// The collection must not be empty.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Returns: The last element of the collection.
    ///
    /// - Complexity: O(1)
    public mutating func removeLast() -> Character {
        return self.content.removeLast()
    }
    /// Removes the specified number of elements from the end of the
    /// collection.
    ///
    /// Attempting to remove more elements than exist in the collection
    /// triggers a runtime error.
    ///
    /// Calling this method may invalidate all saved indices of this
    /// collection. Do not rely on a previously stored index value after
    /// altering a collection with any operation that can change its length.
    ///
    /// - Parameter k: The number of elements to remove from the collection.
    ///   `k` must be greater than or equal to zero and must not exceed the
    ///   number of elements in the collection.
    ///
    /// - Complexity: O(*k*), where *k* is the specified number of elements.
    public mutating func removeLast(_ k: Int) {
        self.content.removeLast(k)
    }
    /// Removes the elements in the specified subrange from the collection.
    ///
    /// All the elements following the specified position are moved to close the
    /// gap. This example removes three elements from the middle of an array of
    /// measurements.
    ///
    ///     var measurements = [1.2, 1.5, 2.9, 1.2, 1.5]
    ///     measurements.removeSubrange(1..<4)
    ///     print(measurements)
    ///     // Prints "[1.2, 1.5]"
    ///
    /// Calling this method may invalidate any existing indices for use with this
    /// collection.
    ///
    /// - Parameter bounds: The range of the collection to be removed. The
    ///   bounds of the range must be valid indices of the collection.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    public mutating func removeSubrange<R>(_ bounds: R) where R : RangeExpression, String.Index == R.Bound {
        self.content.removeSubrange(bounds)
    }
    /// Removes the characters in the given range.
    ///
    /// Calling this method invalidates any existing indices for use with this
    /// string.
    ///
    /// - Parameter bounds: The range of the elements to remove. The upper and
    ///   lower bounds of `bounds` must be valid indices of the string and not
    ///   equal to the string's end index.
    /// - Parameter bounds: The range of the elements to remove. The upper and
    ///   lower bounds of `bounds` must be valid indices of the string.
    public mutating func removeSubrange(_ bounds: Range<String.Index>) {
        self.content.removeSubrange(bounds)
    }
    /// Returns a new collection of the same type containing, in order, the
    /// elements of the original collection that satisfy the given predicate.
    ///
    /// In this example, `filter(_:)` is used to include only names shorter than
    /// five characters.
    ///
    ///     let cast = ["Vivien", "Marlon", "Kim", "Karl"]
    ///     let shortNames = cast.filter { $0.count < 5 }
    ///     print(shortNames)
    ///     // Prints "["Kim", "Karl"]"
    ///
    /// - Parameter isIncluded: A closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be included in the returned collection.
    /// - Returns: A collection of the elements that `isIncluded` allowed.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    public func filter(_ isIncluded: (Character) throws -> Bool) rethrows -> String {
        return try self.content.filter(isIncluded)
    }
    /// Returns a subsequence by skipping elements while `predicate` returns
    /// `true` and returning the remaining elements.
    ///
    /// - Parameter predicate: A closure that takes an element of the
    ///   sequence as its argument and returns `true` if the element should
    ///   be skipped or `false` if it should be included. Once the predicate
    ///   returns `false` it will not be called again.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    public func drop(while predicate: (Character) throws -> Bool) rethrows -> Substring {
        return try self.content.drop(while: predicate)
    }
    /// Returns a subsequence containing all but the first element of the
    /// sequence.
    ///
    /// The following example drops the first element from an array of integers.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.dropFirst())
    ///     // Prints "[2, 3, 4, 5]"
    ///
    /// If the sequence has no elements, the result is an empty subsequence.
    ///
    ///     let empty: [Int] = []
    ///     print(empty.dropFirst())
    ///     // Prints "[]"
    ///
    /// - Returns: A subsequence starting after the first element of the
    ///   sequence.
    ///
    /// - Complexity: O(1)
    public func dropFirst() -> Substring {
        return self.content.dropFirst()
    }
    /// Returns a subsequence containing all but the given number of initial
    /// elements.
    ///
    /// If the number of elements to drop exceeds the number of elements in
    /// the collection, the result is an empty subsequence.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.dropFirst(2))
    ///     // Prints "[3, 4, 5]"
    ///     print(numbers.dropFirst(10))
    ///     // Prints "[]"
    ///
    /// - Parameter k: The number of elements to drop from the beginning of
    ///   the collection. `k` must be greater than or equal to zero.
    /// - Returns: A subsequence starting after the specified number of
    ///   elements.
    ///
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*k*), where *k* is the number of
    ///   elements to drop from the beginning of the collection.
    public func dropFirst(_ k: Int) -> Substring {
        return self.content.dropFirst(k)
    }
    /// Returns a subsequence containing all but the last element of the
    /// sequence.
    ///
    /// The sequence must be finite.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.dropLast())
    ///     // Prints "[1, 2, 3, 4]"
    ///
    /// If the sequence has no elements, the result is an empty subsequence.
    ///
    ///     let empty: [Int] = []
    ///     print(empty.dropLast())
    ///     // Prints "[]"
    ///
    /// - Returns: A subsequence leaving off the last element of the sequence.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    public func dropLast() -> Substring {
        return self.content.dropLast()
    }
    /// Returns a subsequence containing all but the specified number of final
    /// elements.
    ///
    /// If the number of elements to drop exceeds the number of elements in the
    /// collection, the result is an empty subsequence.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.dropLast(2))
    ///     // Prints "[1, 2, 3]"
    ///     print(numbers.dropLast(10))
    ///     // Prints "[]"
    ///
    /// - Parameter k: The number of elements to drop off the end of the
    ///   collection. `k` must be greater than or equal to zero.
    /// - Returns: A subsequence that leaves off `k` elements from the end.
    ///
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*k*), where *k* is the number of
    ///   elements to drop.
    public func dropLast(_ k: Int) -> Substring {
        return self.content.dropLast(k)
    }
    
    /// Returns a Boolean value indicating whether the string begins with the specified prefix.
    ///
    /// - Parameter prefix: A possible prefix to test against this string.
    /// - Returns: true if the string begins with prefix; otherwise, false.
    public func hasPrefix(_ prefix: String) -> Bool {
        return self.content.hasPrefix(prefix)
    }
    /// Returns a Boolean value indicating whether the string ends with the specified suffix.
    ///
    /// - Parameter suffix: A possible suffix to test against this string.
    /// - Returns: true if the string ends with suffix; otherwise, false.
    public func hasSuffix(_ suffix: String) -> Bool {
        return self.content.hasSuffix(suffix)
    }
    /// Returns a subsequence, up to the specified maximum length, containing
    /// the initial elements of the collection.
    ///
    /// If the maximum length exceeds the number of elements in the collection,
    /// the result contains all the elements in the collection.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.prefix(2))
    ///     // Prints "[1, 2]"
    ///     print(numbers.prefix(10))
    ///     // Prints "[1, 2, 3, 4, 5]"
    ///
    /// - Parameter maxLength: The maximum number of elements to return.
    ///   `maxLength` must be greater than or equal to zero.
    /// - Returns: A subsequence starting at the beginning of this collection
    ///   with at most `maxLength` elements.
    ///
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*k*), where *k* is the number of
    ///   elements to select from the beginning of the collection.
    public func prefix(_ maxLength: Int) -> Substring {
        return self.content.prefix(maxLength)
    }
    /// Returns a subsequence from the start of the collection through the
    /// specified position.
    ///
    /// The resulting subsequence *includes* the element at the position `end`.
    /// The following example searches for the index of the number `40` in an
    /// array of integers, and then prints the prefix of the array up to, and
    /// including, that index:
    ///
    ///     let numbers = [10, 20, 30, 40, 50, 60]
    ///     if let i = numbers.firstIndex(of: 40) {
    ///         print(numbers.prefix(through: i))
    ///     }
    ///     // Prints "[10, 20, 30, 40]"
    ///
    /// Using the `prefix(through:)` method is equivalent to using a partial
    /// closed range as the collection's subscript. The subscript notation is
    /// preferred over `prefix(through:)`.
    ///
    ///     if let i = numbers.firstIndex(of: 40) {
    ///         print(numbers[...i])
    ///     }
    ///     // Prints "[10, 20, 30, 40]"
    ///
    /// - Parameter end: The index of the last element to include in the
    ///   resulting subsequence. `end` must be a valid index of the collection
    ///   that is not equal to the `endIndex` property.
    /// - Returns: A subsequence up to, and including, the `end` position.
    ///
    /// - Complexity: O(1)
    public func prefix(through position: String.Index) -> Substring {
        return self.content.prefix(through: position)
    }
    /// Returns a subsequence from the start of the collection up to, but not
    /// including, the specified position.
    ///
    /// The resulting subsequence *does not include* the element at the position
    /// `end`. The following example searches for the index of the number `40`
    /// in an array of integers, and then prints the prefix of the array up to,
    /// but not including, that index:
    ///
    ///     let numbers = [10, 20, 30, 40, 50, 60]
    ///     if let i = numbers.firstIndex(of: 40) {
    ///         print(numbers.prefix(upTo: i))
    ///     }
    ///     // Prints "[10, 20, 30]"
    ///
    /// Passing the collection's starting index as the `end` parameter results in
    /// an empty subsequence.
    ///
    ///     print(numbers.prefix(upTo: numbers.startIndex))
    ///     // Prints "[]"
    ///
    /// Using the `prefix(upTo:)` method is equivalent to using a partial
    /// half-open range as the collection's subscript. The subscript notation is
    /// preferred over `prefix(upTo:)`.
    ///
    ///     if let i = numbers.firstIndex(of: 40) {
    ///         print(numbers[..<i])
    ///     }
    ///     // Prints "[10, 20, 30]"
    ///
    /// - Parameter end: The "past the end" index of the resulting subsequence.
    ///   `end` must be a valid index of the collection.
    /// - Returns: A subsequence up to, but not including, the `end` position.
    ///
    /// - Complexity: O(1)
    public func prefix(upTo end: String.Index) -> Substring {
        return self.content.prefix(upTo: end)
    }
    /// Returns a subsequence containing the initial elements until `predicate`
    /// returns `false` and skipping the remaining elements.
    ///
    /// - Parameter predicate: A closure that takes an element of the
    ///   sequence as its argument and returns `true` if the element should
    ///   be included or `false` if it should be excluded. Once the predicate
    ///   returns `false` it will not be called again.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the collection.
    public func prefix(while predicate: (Character) throws -> Bool) rethrows -> Substring {
        return try self.content.prefix(while: predicate)
    }
    /// Returns a subsequence, up to the given maximum length, containing the
    /// final elements of the collection.
    ///
    /// If the maximum length exceeds the number of elements in the collection,
    /// the result contains the entire collection.
    ///
    ///     let numbers = [1, 2, 3, 4, 5]
    ///     print(numbers.suffix(2))
    ///     // Prints "[4, 5]"
    ///     print(numbers.suffix(10))
    ///     // Prints "[1, 2, 3, 4, 5]"
    ///
    /// - Parameter maxLength: The maximum number of elements to return.
    ///   `maxLength` must be greater than or equal to zero.
    /// - Returns: A subsequence terminating at the end of the collection with at
    ///   most `maxLength` elements.
    ///
    /// - Complexity: O(1) if the collection conforms to
    ///   `RandomAccessCollection`; otherwise, O(*k*), where *k* is equal to
    ///   `maxLength`.
    public func suffix(_ maxLength: Int) -> Substring {
        return self.content.suffix(maxLength)
    }
    /// Returns a subsequence from the specified position to the end of the
    /// collection.
    ///
    /// The following example searches for the index of the number `40` in an
    /// array of integers, and then prints the suffix of the array starting at
    /// that index:
    ///
    ///     let numbers = [10, 20, 30, 40, 50, 60]
    ///     if let i = numbers.firstIndex(of: 40) {
    ///         print(numbers.suffix(from: i))
    ///     }
    ///     // Prints "[40, 50, 60]"
    ///
    /// Passing the collection's `endIndex` as the `start` parameter results in
    /// an empty subsequence.
    ///
    ///     print(numbers.suffix(from: numbers.endIndex))
    ///     // Prints "[]"
    ///
    /// Using the `suffix(from:)` method is equivalent to using a partial range
    /// from the index as the collection's subscript. The subscript notation is
    /// preferred over `suffix(from:)`.
    ///
    ///     if let i = numbers.firstIndex(of: 40) {
    ///         print(numbers[i...])
    ///     }
    ///     // Prints "[40, 50, 60]"
    ///
    /// - Parameter start: The index at which to start the resulting subsequence.
    ///   `start` must be a valid index of the collection.
    /// - Returns: A subsequence starting at the `start` position.
    ///
    /// - Complexity: O(1)
    public func suffix(from start: String.Index) -> Substring {
        return self.content.suffix(from: start)
    }
    
}

public extension StringFile {
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    ///
    /// - Parameter element: The element to find in the sequence.
    /// - Returns: true if the element was found in the sequence; otherwise, false.
    func contains(_ element: Character) -> Bool {
        return self.content.contains(element)
    }
    /// Returns a Boolean value indicating whether the sequence contains an element that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: true if the sequence contains an element that satisfies predicate; otherwise, false.
    func contains(where predicate: (Character) throws -> Bool) rethrows -> Bool {
        return try self.content.contains(where: predicate)
    }
    /// Returns the first element of the sequence that satisfies the given
    /// predicate.
    ///
    /// The following example uses the `first(where:)` method to find the first
    /// negative number in an array of integers:
    ///
    ///     let numbers = [3, 7, 4, -2, 9, -6, 10, 1]
    ///     if let firstNegative = numbers.first(where: { $0 < 0 }) {
    ///         print("The first negative number is \(firstNegative).")
    ///     }
    ///     // Prints "The first negative number is -2."
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as
    ///   its argument and returns a Boolean value indicating whether the
    ///   element is a match.
    /// - Returns: The first element of the sequence that satisfies `predicate`,
    ///   or `nil` if there is no element that satisfies `predicate`.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the sequence.
    func first(where predicate: (Character) throws -> Bool) rethrows -> Character? {
        return try self.content.first(where: predicate)
    }
    
    /// Returns the first index where the specified value appears in the collection.
    ///
    /// - Parameter element: An element to search for in the collection.
    /// - Returns: The first index where element is found. If element is not found in the collection, returns nil.
    func index(of element: Character) -> String.Index? {
        return self.content.firstIndex(of: element)
    }
    
    /// Returns the first index in which an element of the collection satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: The index of the first element for which predicate returns true. If no elements in the collection satisfy the given predicate, returns nil.
    func index(where predicate: (Character) throws -> Bool) rethrows -> String.Index? {
        return try self.content.firstIndex(where: predicate)
    }
}

public extension StringFile {
    static func +=(lhs: inout StringFile, rhs: String) {
        lhs.content += rhs
    }
    static func +=(lhs: inout String, rhs: StringFile) {
        lhs += rhs.content
    }
}
