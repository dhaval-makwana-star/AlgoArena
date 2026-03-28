require("dotenv").config();

const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*", methods: ["GET", "POST"] },
  pingTimeout: 60000,
  pingInterval: 25000,
});

// ─── IMPORTANT: Load API key from environment variable ───────────────────────
// Set GEMINI_API_KEY in your .env file or hosting environment. Never hardcode.
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;

app.get("/", (req, res) => {
  res.json({
    status: "AlgoArena Server 🚀",
    rooms: Object.keys(rooms).length,
    connectedPlayers: Object.keys(uidMap).length,
  });
});

// ─── DSA Question Bank (Room 101 / Open Arena) ──────────────────────────────
const DSA_QUESTIONS = [
  { question: "What is the time complexity of Binary Search?", correctAnswer: "o(log n)", display: "O(log n)", complexity: "Easy", timeLimit: 30 },
  { question: "Which data structure uses LIFO order?", correctAnswer: "stack", display: "Stack", complexity: "Easy", timeLimit: 30 },
  { question: "What is the worst-case time complexity of QuickSort?", correctAnswer: "o(n^2)", display: "O(n^2)", complexity: "Medium", timeLimit: 45 },
  { question: "What data structure is used in BFS traversal?", correctAnswer: "queue", display: "Queue", complexity: "Easy", timeLimit: 30 },
  { question: "What is the space complexity of Merge Sort?", correctAnswer: "o(n)", display: "O(n)", complexity: "Medium", timeLimit: 45 },
  { question: "In a min-heap, where is the smallest element?", correctAnswer: "root", display: "Root", complexity: "Easy", timeLimit: 30 },
  { question: "What traversal gives sorted output from a BST?", correctAnswer: "inorder", display: "Inorder", complexity: "Medium", timeLimit: 45 },
  { question: "Average time complexity of inserting into a Hash Table?", correctAnswer: "o(1)", display: "O(1)", complexity: "Medium", timeLimit: 45 },
  { question: "Which algorithm finds shortest path in a weighted graph?", correctAnswer: "dijkstra", display: "Dijkstra", complexity: "Hard", timeLimit: 60 },
  { question: "Time complexity of building a heap from an array?", correctAnswer: "o(n)", display: "O(n)", complexity: "Hard", timeLimit: 60 },
  { question: "Data structure DFS uses internally (ignoring recursion)?", correctAnswer: "stack", display: "Stack", complexity: "Medium", timeLimit: 45 },
  { question: "Time complexity of accessing an array element by index?", correctAnswer: "o(1)", display: "O(1)", complexity: "Easy", timeLimit: 30 },
  { question: "Which sorting algorithm is stable with O(n log n) average?", correctAnswer: "merge sort", display: "Merge Sort", complexity: "Medium", timeLimit: 45 },
  { question: "Height of a complete binary tree with N nodes?", correctAnswer: "o(log n)", display: "O(log n)", complexity: "Hard", timeLimit: 60 },
  { question: "Which data structure is used internally by recursion?", correctAnswer: "stack", display: "Stack", complexity: "Easy", timeLimit: 30 },
  { question: "Time complexity of linear search in worst case?", correctAnswer: "o(n)", display: "O(n)", complexity: "Easy", timeLimit: 30 },
  { question: "Which algorithm uses divide and conquer to sort?", correctAnswer: "merge sort", display: "Merge Sort", complexity: "Medium", timeLimit: 45 },
  { question: "Best case time complexity of Bubble Sort?", correctAnswer: "o(n)", display: "O(n)", complexity: "Easy", timeLimit: 30 },
  { question: "What is a balanced BST that auto-rebalances?", correctAnswer: "avl tree", display: "AVL Tree", complexity: "Hard", timeLimit: 60 },
  { question: "Time complexity of finding an element in a balanced BST?", correctAnswer: "o(log n)", display: "O(log n)", complexity: "Medium", timeLimit: 45 },
];

// ─── Syntax Game Questions ───────────────────────────────────────────────────
const SYNTAX_QUESTIONS = [
  {
    question: "Complete the Python list comprehension: squares = [___ for x in range(10)]",
    options: ["x*x", "x^2", "x**x", "pow(x)"],
    correctIndex: 0,
    explanation: "x*x or x**2 gives the square. x*x is the standard multiplication syntax.",
    category: "Python", xp: 10
  },
  {
    question: "Which is the correct way to declare a variable in Java?",
    options: ["int x = 5;", "x = 5;", "var x: int = 5;", "declare int x = 5;"],
    correctIndex: 0,
    explanation: "Java requires explicit type declaration: int x = 5;",
    category: "Java", xp: 10
  },
  {
    question: "What does 'arr.sort()' return in Python?",
    options: ["None", "sorted list", "new list", "True"],
    correctIndex: 0,
    explanation: "Python's list.sort() sorts in-place and returns None. Use sorted(arr) for a new list.",
    category: "Python", xp: 15
  },
  {
    question: "Correct syntax for a lambda in Python that adds two numbers?",
    options: ["lambda x, y: x + y", "lambda(x, y): x + y", "fn x, y => x + y", "def lambda(x,y): x+y"],
    correctIndex: 0,
    explanation: "Python lambda syntax: lambda args: expression",
    category: "Python", xp: 15
  },
  {
    question: "Which operator checks reference equality in Java?",
    options: ["==", ".equals()", "===", "is"],
    correctIndex: 0,
    explanation: "In Java, == checks reference equality for objects. Use .equals() for value comparison.",
    category: "Java", xp: 20
  },
  {
    question: "Correct C++ syntax to declare a vector of integers?",
    options: ["vector<int> v;", "int[] v;", "List<int> v;", "Array<int> v;"],
    correctIndex: 0,
    explanation: "C++ STL vector: vector<int> v; — include <vector> header.",
    category: "C++", xp: 20
  },
  {
    question: "How do you declare an interface in Java?",
    options: ["interface MyInterface {}", "abstract MyInterface {}", "trait MyInterface {}", "protocol MyInterface {}"],
    correctIndex: 0,
    explanation: "Java uses the 'interface' keyword to declare interfaces.",
    category: "Java", xp: 15
  },
  {
    question: "Python dict comprehension to map numbers to squares: ___",
    options: ["{x: x**2 for x in range(5)}", "[x: x**2 for x in range(5)]", "{x => x**2 for x in range(5)}", "dict(x: x**2 for x in range(5))"],
    correctIndex: 0,
    explanation: "Dict comprehension uses {} with key:value pairs.",
    category: "Python", xp: 20
  },
  {
    question: "Correct way to handle exceptions in Python?",
    options: ["try: ... except Exception as e:", "try: ... catch Exception e:", "try { } catch(e) { }", "begin ... rescue e:"],
    correctIndex: 0,
    explanation: "Python uses try/except blocks, not try/catch like Java/C++.",
    category: "Python", xp: 15
  },
  {
    question: "Which syntax creates a HashSet in Java?",
    options: ["Set<Integer> s = new HashSet<>();", "HashSet s = new Set<Integer>();", "Set s = HashSet<Integer>();", "new HashSet<Integer> s;"],
    correctIndex: 0,
    explanation: "Java: Set<Type> varName = new HashSet<>(); — uses diamond operator.",
    category: "Java", xp: 20
  },
  {
    question: "C++ syntax to iterate over a vector using range-based for?",
    options: ["for (int x : v) {}", "for (int x in v) {}", "for each (int x in v) {}", "foreach (int x : v) {}"],
    correctIndex: 0,
    explanation: "C++11 range-based for: for (type var : container) — uses colon, not 'in'.",
    category: "C++", xp: 20
  },
  {
    question: "Python: How to get all keys from a dictionary 'd'?",
    options: ["d.keys()", "d.getKeys()", "keys(d)", "d[keys]"],
    correctIndex: 0,
    explanation: "Python dict.keys() returns a view of all keys in the dictionary.",
    category: "Python", xp: 10
  },
  {
    question: "Correct Java syntax for a generic method?",
    options: ["public <T> T method(T arg) {}", "public T method<T>(T arg) {}", "public method<T>(T arg): T {}", "generic T method(T arg) {}"],
    correctIndex: 0,
    explanation: "Java generic methods: type parameter <T> comes before return type.",
    category: "Java", xp: 25
  },
  {
    question: "How to reverse a list in Python without creating a new one?",
    options: ["lst.reverse()", "reversed(lst)", "lst[::-1]", "lst.sort(reverse=True)"],
    correctIndex: 0,
    explanation: "lst.reverse() reverses in-place. reversed() and [::-1] create new iterators/lists.",
    category: "Python", xp: 15
  },
  {
    question: "C++ syntax to push to a stack?",
    options: ["st.push(x);", "st.add(x);", "st.append(x);", "st.insert(x);"],
    correctIndex: 0,
    explanation: "C++ stack uses push() to add elements and pop() to remove the top.",
    category: "C++", xp: 15
  },
];

// ─── Debug Game Questions ────────────────────────────────────────────────────
const DEBUG_QUESTIONS = [
  {
    buggyCode: "def binary_search(arr, target):\n    left, right = 0, len(arr)\n    while left < right:\n        mid = (left + right) // 2\n        if arr[mid] == target: return mid\n        elif arr[mid] < target: left = mid + 1\n        else: right = mid - 1\n    return -1",
    question: "Find the bug in this binary search:",
    options: ["right = len(arr) should be len(arr)-1", "mid formula is wrong", "return -1 is missing", "while condition wrong"],
    correctIndex: 0,
    explanation: "right should be len(arr)-1 (last valid index). len(arr) causes index out of bounds.",
    difficulty: "Medium", xp: 25, coins: 15
  },
  {
    buggyCode: "def fibonacci(n):\n    if n <= 0: return 0\n    if n == 1: return 1\n    return fibonacci(n-1) + fibonacci(n-3)",
    question: "Spot the bug in this Fibonacci function:",
    options: ["Should be fibonacci(n-2) not fibonacci(n-3)", "Base case n==1 is wrong", "n<=0 should be n<0", "Return type is wrong"],
    correctIndex: 0,
    explanation: "Fibonacci: F(n) = F(n-1) + F(n-2), not F(n-3). This returns wrong values.",
    difficulty: "Easy", xp: 15, coins: 10
  },
  {
    buggyCode: "int[] arr = new int[5];\nfor (int i = 0; i <= arr.length; i++) {\n    arr[i] = i * 2;\n}",
    question: "What's wrong with this Java loop?",
    options: ["i <= arr.length causes ArrayIndexOutOfBoundsException", "arr.length should be arr.size()", "int[] declaration is wrong", "i * 2 should be i + 2"],
    correctIndex: 0,
    explanation: "Array indices are 0 to length-1. i <= length accesses index 5 on a size-5 array → exception.",
    difficulty: "Easy", xp: 15, coins: 10
  },
  {
    buggyCode: "def reverse_string(s):\n    result = ''\n    for i in range(len(s)):\n        result = result + s[i]\n    return result",
    question: "This function should reverse a string but doesn't. Find the bug:",
    options: ["Should be result = s[i] + result", "range should be range(len(s)-1, -1, -1)", "result += s[i] is needed", "return result[::-1]"],
    correctIndex: 0,
    explanation: "To prepend: result = s[i] + result. Appending s[i] to result just copies the string.",
    difficulty: "Easy", xp: 15, coins: 10
  },
  {
    buggyCode: "vector<int> v = {1, 2, 3, 4, 5};\nfor (int i = 0; i < v.size(); i++) {\n    if (v[i] % 2 == 0)\n        v.erase(v.begin() + i);\n}",
    question: "This C++ code tries to remove even numbers. What's the bug?",
    options: ["Erasing while iterating skips elements; don't increment i after erase", "v.size() should be v.length()", "v.erase needs two iterators", "Condition should be % 2 != 0"],
    correctIndex: 0,
    explanation: "After erasing at index i, next element shifts to i. Without adjusting i, the element after erased one is skipped.",
    difficulty: "Hard", xp: 35, coins: 20
  },
  {
    buggyCode: "def has_cycle(head):\n    slow = fast = head\n    while fast and fast.next:\n        slow = slow.next\n        fast = fast.next\n    return slow == fast",
    question: "Bug in this linked list cycle detection:",
    options: ["fast should move 2 steps: fast = fast.next.next", "slow should also move 2 steps", "Condition should be while slow != fast", "Return should check fast is None"],
    correctIndex: 0,
    explanation: "Floyd's algorithm: fast must move 2 steps (fast.next.next) while slow moves 1. Without this, they always meet.",
    difficulty: "Hard", xp: 35, coins: 20
  },
  {
    buggyCode: "public int maxDepth(TreeNode root) {\n    if (root == null) return 0;\n    return 1 + maxDepth(root.left) + maxDepth(root.right);\n}",
    question: "This should return max depth of a binary tree. Find the bug:",
    options: ["Should use Math.max(left, right) not add them", "Base case should return 1 not 0", "Should check root.left == null", "Recursion order is wrong"],
    correctIndex: 0,
    explanation: "Max depth = 1 + max(left depth, right depth). Adding them gives the total node count, not depth.",
    difficulty: "Medium", xp: 25, coins: 15
  },
  {
    buggyCode: "def two_sum(nums, target):\n    seen = {}\n    for i, num in enumerate(nums):\n        complement = target + num\n        if complement in seen:\n            return [seen[complement], i]\n        seen[num] = i\n    return []",
    question: "Bug in this Two Sum solution:",
    options: ["Should be target - num, not target + num", "seen should be a list", "enumerate is not needed", "Return should be indices not values"],
    correctIndex: 0,
    explanation: "complement = target - num (what we need to find). target + num is the sum of current + num which is wrong.",
    difficulty: "Medium", xp: 25, coins: 15
  },
];

// ─── Logic Game Questions ────────────────────────────────────────────────────
const LOGIC_QUESTIONS = [
  {
    question: "You have 8 balls, one is heavier. Using a balance scale, what's the minimum weighings needed to find the heavy ball?",
    options: ["2", "3", "1", "4"],
    correctIndex: 0,
    explanation: "Weigh 3v3. If balanced, heavy is in remaining 2 (1 more weighing). If unbalanced, weigh 1v1 from heavy group. Total: 2 weighings.",
    category: "Puzzles", xp: 30
  },
  {
    question: "An array has all elements appearing twice except one. Which approach finds the unique element in O(n) time, O(1) space?",
    options: ["XOR all elements", "Sort and scan", "HashMap counting", "Binary search"],
    correctIndex: 0,
    explanation: "XOR of same numbers = 0. XORing all: duplicates cancel, leaving the unique element. O(n) time, O(1) space.",
    category: "Bit Manipulation", xp: 25
  },
  {
    question: "To check if a number N is a power of 2, which is the most efficient?",
    options: ["N > 0 && (N & (N-1)) == 0", "N % 2 == 0", "Math.log2(N) == floor", "Loop dividing by 2"],
    correctIndex: 0,
    explanation: "Powers of 2 have exactly one bit set. N-1 flips all bits after that bit. AND gives 0 only for powers of 2.",
    category: "Bit Manipulation", xp: 25
  },
  {
    question: "Given a sorted rotated array, how do you find an element in O(log n)?",
    options: ["Modified binary search checking which half is sorted", "Linear scan from pivot", "Two pointer approach", "Merge sort then binary search"],
    correctIndex: 0,
    explanation: "At each mid, one half is sorted. Check if target is in sorted half → recurse there. Other half contains the rotation.",
    category: "Binary Search", xp: 30
  },
  {
    question: "Which approach solves the 'Coin Change' problem optimally?",
    options: ["Dynamic Programming (bottom-up)", "Greedy always picking largest coin", "Backtracking with pruning", "Binary Search on answer"],
    correctIndex: 0,
    explanation: "Greedy fails (e.g., coins=[1,3,4], amount=6: greedy picks 4+1+1=3 coins but 3+3=2 is optimal). DP guarantees optimal.",
    category: "Dynamic Programming", xp: 35
  },
  {
    question: "Best data structure to find the k-th largest element efficiently with streaming data?",
    options: ["Min-heap of size k", "Max-heap", "Sorted array", "Hash table"],
    correctIndex: 0,
    explanation: "Maintain a min-heap of size k. The root is always the k-th largest. O(n log k) total, O(log k) per insertion.",
    category: "Heaps", xp: 30
  },
  {
    question: "To detect if a linked list has a cycle, which approach uses O(1) space?",
    options: ["Floyd's two-pointer (fast & slow)", "HashSet of visited nodes", "Array of node addresses", "Counting nodes and checking"],
    correctIndex: 0,
    explanation: "Floyd's algorithm: fast pointer moves 2 steps, slow moves 1. If cycle exists, they meet. No extra space needed.",
    category: "Linked Lists", xp: 25
  },
  {
    question: "Which technique reduces time complexity of naive recursive solutions by storing subproblem results?",
    options: ["Memoization", "Tabulation", "Both Memoization and Tabulation", "Pruning"],
    correctIndex: 2,
    explanation: "Both memoization (top-down) and tabulation (bottom-up) are DP techniques that store subproblem results to avoid recomputation.",
    category: "Dynamic Programming", xp: 20
  },
  {
    question: "What is the optimal strategy to merge K sorted lists of total N elements?",
    options: ["Use a min-heap with one element from each list", "Merge lists pairwise repeatedly", "Concatenate all and sort", "Use K pointers scanning simultaneously"],
    correctIndex: 0,
    explanation: "Min-heap approach: O(N log K). Always extract min, push next from that list. Far better than O(NK) naive approach.",
    category: "Heaps", xp: 35
  },
  {
    question: "Which graph algorithm detects negative cycles?",
    options: ["Bellman-Ford", "Dijkstra", "Floyd-Warshall", "BFS"],
    correctIndex: 0,
    explanation: "Bellman-Ford relaxes edges V-1 times. If relaxation is still possible on the V-th pass, a negative cycle exists.",
    category: "Graphs", xp: 30
  },
];

// ─── Speed Game Questions (multi-difficulty) ─────────────────────────────────
const SPEED_QUESTIONS = {
  easy: [
    { question: "Time complexity of accessing array by index?", answer: "o(1)", display: "O(1)" },
    { question: "LIFO data structure?", answer: "stack", display: "Stack" },
    { question: "FIFO data structure?", answer: "queue", display: "Queue" },
    { question: "Linked list node has data and?", answer: "pointer", display: "Pointer/Next" },
    { question: "Binary search requires array to be?", answer: "sorted", display: "Sorted" },
    { question: "Number of edges in a complete graph with N nodes?", answer: "n(n-1)/2", display: "N(N-1)/2" },
    { question: "Stack operation to add element?", answer: "push", display: "Push" },
    { question: "Stack operation to remove top element?", answer: "pop", display: "Pop" },
    { question: "Root of min-heap contains?", answer: "minimum", display: "Minimum" },
    { question: "DFS stands for?", answer: "depth first search", display: "Depth First Search" },
  ],
  medium: [
    { question: "Average case time complexity of QuickSort?", answer: "o(n log n)", display: "O(N log N)" },
    { question: "Space complexity of DFS on a graph with V vertices?", answer: "o(v)", display: "O(V)" },
    { question: "What traversal visits root, left, right?", answer: "preorder", display: "Preorder" },
    { question: "What traversal visits left, root, right?", answer: "inorder", display: "Inorder" },
    { question: "What traversal visits left, right, root?", answer: "postorder", display: "Postorder" },
    { question: "Time complexity of heapify operation?", answer: "o(log n)", display: "O(log N)" },
    { question: "Dijkstra fails when graph has?", answer: "negative weights", display: "Negative Weights" },
    { question: "AVL tree maximum height difference between subtrees?", answer: "1", display: "1" },
    { question: "Hash collision resolution using linked lists is called?", answer: "chaining", display: "Chaining" },
    { question: "Time complexity of building a heap?", answer: "o(n)", display: "O(N)" },
  ],
  hard: [
    { question: "Time complexity of Knuth-Morris-Pratt (KMP) algorithm?", answer: "o(n+m)", display: "O(N+M)" },
    { question: "Which tree structure is used in databases for indexing?", answer: "b-tree", display: "B-Tree" },
    { question: "Time to find strongly connected components (Kosaraju)?", answer: "o(v+e)", display: "O(V+E)" },
    { question: "What problem does topological sort solve?", answer: "dependency ordering", display: "Dependency Ordering" },
    { question: "Minimum spanning tree algorithm using union-find?", answer: "kruskal", display: "Kruskal's" },
    { question: "Space complexity of recursive DFS on a balanced binary tree?", answer: "o(log n)", display: "O(log N)" },
    { question: "What does NP-Hard mean?", answer: "at least as hard as np", display: "At Least as Hard as NP" },
    { question: "Lower bound of comparison-based sorting?", answer: "o(n log n)", display: "Ω(N log N)" },
    { question: "Floyd-Warshall time complexity?", answer: "o(v^3)", display: "O(V³)" },
    { question: "Segment tree time for range query?", answer: "o(log n)", display: "O(log N)" },
  ],
};

// ─── State ──────────────────────────────────────────────────────────────────
let rooms = {};
let uidMap = {};
let nameMap = {};

// ─── AI Battle Room Storage ──────────────────────────────────────────────────
const aiBattleRooms = {};

function getRandQ(bank) {
  return bank[Math.floor(Math.random() * bank.length)];
}

function cleanRoom(name) {
  const r = rooms[name];
  if (!r) return;
  if (r.timerId) clearTimeout(r.timerId);
  if (r.countdownId) clearInterval(r.countdownId);
  delete rooms[name];
  console.log(`🗑️  Room "${name}" cleaned up`);
}

// ─── Helper: random integer in range ────────────────────────────────────────
function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// ─── Helper: pick random item from array ────────────────────────────────────
function randItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// ─── AI Bot Personalities ────────────────────────────────────────────────────
const BOT_PERSONAS = [
  {
    name: "GlitchBot",
    emoji: "🤖",
    taunts: ["My circuits are warming up...", "Processing your defeat...", "Too slow, human."],
    winLines: ["Did you even try?", "Better luck next time, carbon unit."],
    loseLines: ["Impossible... recalibrating...", "You got lucky. Next round won't be pretty."],
  },
  {
    name: "NeuralX",
    emoji: "🧠",
    taunts: ["My neural weights say you're losing.", "I've solved this 40,000 times before.", "Calculating your failure probability..."],
    winLines: ["Humans are so predictable.", "That's 99.97% win rate for me."],
    loseLines: ["Anomaly detected. Learning from you...", "You've triggered my adaptation mode."],
  },
  {
    name: "CodeDemon",
    emoji: "👾",
    taunts: ["I breathe DSA.", "Don't blink.", "Your slowness amuses me."],
    winLines: ["Git rekt.", "I don't lose. Only compile errors stop me."],
    loseLines: ["Stack overflow in my ego...", "Fine. You earned that."],
  },
];

// ─── Difficulty Settings ─────────────────────────────────────────────────────
function getAiDifficulty(userWinStreak) {
  if (userWinStreak <= 1) return { level: "Easy",   minDelay: 25, maxDelay: 40, mistakeChance: 0.30, label: "Rookie"   };
  if (userWinStreak <= 3) return { level: "Medium", minDelay: 15, maxDelay: 25, mistakeChance: 0.15, label: "Pro"      };
  if (userWinStreak <= 5) return { level: "Hard",   minDelay: 8,  maxDelay: 15, mistakeChance: 0.05, label: "Elite"    };
  return                         { level: "Legend", minDelay: 3,  maxDelay: 8,  mistakeChance: 0.00, label: "Legend"   };
}

// ─── Call Gemini to Generate a Battle Question ───────────────────────────────
async function generateAiQuestion(difficulty) {
  // FIX: If no API key configured, immediately fall back to local questions
  if (!GEMINI_API_KEY) {
    console.warn("⚠️ No GEMINI_API_KEY set. Using fallback question bank.");
    return getRandQ(DSA_QUESTIONS);
  }

  const diffMap = {
    Easy:   "beginner-level (basic arrays, stacks, queues)",
    Medium: "intermediate-level (trees, sorting, recursion)",
    Hard:   "advanced-level (graphs, DP, heaps)",
    Legend: "expert-level (complex DP, advanced graph algorithms)",
  };

  const prompt = `
    Generate a single ${diffMap[difficulty] || "medium-level"} Data Structures and Algorithms quiz question.

    Rules:
    - The question should have a SHORT, single-word or short-phrase answer (e.g. "O(log n)", "Stack", "Merge Sort")
    - The answer must be unambiguous
    - Do NOT generate multiple choice — just question + answer
    - Respond ONLY in this exact JSON format with no extra text:
    {
      "question": "Your question here?",
      "answer": "short answer",
      "hint": "one-line hint about answer format",
      "explanation": "one sentence explanation of the answer"
    }
  `;

  try {
    const res = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.7, maxOutputTokens: 300 },
      }),
    });

    // FIX: Check HTTP status before parsing
    if (!res.ok) {
      throw new Error(`Gemini API error: ${res.status} ${res.statusText}`);
    }

    const data = await res.json();
    const raw = data.candidates?.[0]?.content?.parts?.[0]?.text || "";
    // Strip markdown code fences if Gemini wraps in ```json
    const clean = raw.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(clean);
    return {
      question: parsed.question,
      correctAnswer: parsed.answer.toLowerCase().trim(),
      display: parsed.answer,
      hint: parsed.hint,
      explanation: parsed.explanation,
      aiGenerated: true,
    };
  } catch (err) {
    console.error("⚠️ Gemini failed, using fallback question:", err.message);
    return getRandQ(DSA_QUESTIONS);
  }
}

// ─── AI Battle Socket Handlers ───────────────────────────────────────────────
function registerAiBattleHandlers(socket) {

  // Player taps "JOIN ROOM" on AI Battle card
  socket.on("joinAiBattle", async ({ uid, username, aiStreak }) => {
    // FIX: Guard against missing uid/username
    if (!uid) {
      socket.emit("aiBattleError", { message: "Authentication error. Please restart the app." });
      return;
    }

    const roomId = `ai_${socket.id}`;
    const difficulty = getAiDifficulty(aiStreak || 0);
    const persona = randItem(BOT_PERSONAS);

    console.log(`🤖 AI Battle: ${username} vs ${persona.name} [${difficulty.level}]`);

    // Tell the player they're in — show bot card immediately
    socket.emit("aiBattleJoined", {
      roomId,
      bot: { name: persona.name, emoji: persona.emoji, level: difficulty.label },
      difficulty: difficulty.level,
    });

    // Fetch question from Gemini (or fallback)
    socket.emit("aiBattleStatus", { message: "🧠 Generating your challenge..." });
    const question = await generateAiQuestion(difficulty.level);

    // FIX: Check if socket is still connected after async Gemini call
    if (!socket.connected) {
      console.log(`⚠️ Socket ${socket.id} disconnected during question generation.`);
      return;
    }

    // Store the room state
    aiBattleRooms[roomId] = {
      socketId: socket.id,
      uid,
      username,
      question,
      difficulty,
      persona,
      finished: false,
      aiAnswered: false,
      playerAnswered: false,
      startedAt: Date.now(),
    };

    // 3-second countdown then start
    let cd = 3;
    const countdownInterval = setInterval(() => {
      socket.emit("aiBattleCountdown", { count: cd });
      cd--;
      if (cd < 0) {
        clearInterval(countdownInterval);
        _startAiBattle(socket, roomId);
      }
    }, 1000);
  });

  // Player submits their answer
  socket.on("submitAiBattleAnswer", ({ roomId, answer }) => {
    const room = aiBattleRooms[roomId];
    if (!room || room.finished) return;

    const submitted = (answer || "").toLowerCase().trim();
    const correct = room.question.correctAnswer.toLowerCase().trim();

    if (submitted === correct) {
      room.finished = true;
      room.playerAnswered = true;
      if (room.aiTimer) clearTimeout(room.aiTimer);
      if (room.globalTimer) clearTimeout(room.globalTimer);

      socket.emit("aiBattleFinished", {
        winner: "player",
        message: `🏆 You beat ${room.persona.name}!`,
        botLine: randItem(room.persona.loseLines),
        explanation: room.question.explanation,
        coinsEarned: _coinsForDifficulty(room.difficulty.level),
        xpEarned: _xpForDifficulty(room.difficulty.level),
        correctAnswer: room.question.display,
      });
      _cleanAiRoom(roomId);
    } else {
      // Wrong answer — send taunt from bot
      socket.emit("aiBattleWrongAnswer", {
        taunt: randItem(room.persona.taunts),
      });
    }
  });
}

// ─── Internal: Start the AI Battle ───────────────────────────────────────────
function _startAiBattle(socket, roomId) {
  const room = aiBattleRooms[roomId];
  if (!room) return;

  const { question, difficulty, persona } = room;

  // Send the question to the player
  socket.emit("aiBattleStarted", {
    question: question.question,
    hint: question.hint,
    difficulty: difficulty.level,
    timeLimit: 60,
    botName: persona.name,
    botEmoji: persona.emoji,
    openingTaunt: randItem(persona.taunts),
  });

  // Schedule AI "thinking" events — fake typing at intervals
  const thinkDelay = randInt(difficulty.minDelay, difficulty.maxDelay) * 1000;

  // Bot sends progress updates (the "typing..." effect)
  const thinkSteps = 4;
  for (let i = 1; i <= thinkSteps; i++) {
    setTimeout(() => {
      if (room.finished) return;
      const progress = Math.round((i / thinkSteps) * 100);
      socket.emit("aiBattleThinking", {
        progress,
        taunt: i === thinkSteps ? "Almost there..." : randItem(persona.taunts),
      });
    }, (thinkDelay / thinkSteps) * i - randInt(500, 1500));
  }

  // Schedule AI answer — maybe wrong first (mistakeChance)
  room.aiTimer = setTimeout(() => {
    if (room.finished) return;

    const makesMistake = Math.random() < difficulty.mistakeChance;
    if (makesMistake) {
      // Bot submits wrong, gives player a chance
      socket.emit("aiBattleThinking", { progress: 80, taunt: "Wait... let me recalculate..." });
      // Bot tries again 5-10 seconds later
      setTimeout(() => {
        if (room.finished) return;
        room.finished = true;
        room.aiAnswered = true;
        socket.emit("aiBattleFinished", {
          winner: "bot",
          message: `💀 ${persona.name} figured it out! You lost.`,
          botLine: randItem(persona.winLines),
          explanation: question.explanation,
          correctAnswer: question.display,
          coinsEarned: 0,
          xpEarned: 5,
        });
        _cleanAiRoom(roomId);
      }, randInt(5, 10) * 1000);
    } else {
      room.finished = true;
      room.aiAnswered = true;
      socket.emit("aiBattleFinished", {
        winner: "bot",
        message: `💀 ${persona.name} answered first! You lost.`,
        botLine: randItem(persona.winLines),
        explanation: question.explanation,
        correctAnswer: question.display,
        coinsEarned: 0,
        xpEarned: 5,
      });
      _cleanAiRoom(roomId);
    }
  }, thinkDelay);

  // Global time limit fallback (60s)
  room.globalTimer = setTimeout(() => {
    if (room.finished) return;
    room.finished = true;
    socket.emit("aiBattleFinished", {
      winner: "timeout",
      message: "⏰ Time's up! Nobody wins.",
      botLine: "Even I couldn't solve it in time...",
      explanation: question.explanation,
      correctAnswer: question.display,
      coinsEarned: 0,
      xpEarned: 2,
    });
    _cleanAiRoom(roomId);
  }, 60000);
}

function _coinsForDifficulty(level) {
  return { Easy: 20, Medium: 50, Hard: 100, Legend: 250 }[level] || 20;
}

function _xpForDifficulty(level) {
  return { Easy: 10, Medium: 25, Hard: 50, Legend: 100 }[level] || 10;
}

function _cleanAiRoom(roomId) {
  const room = aiBattleRooms[roomId];
  if (room) {
    if (room.aiTimer) clearTimeout(room.aiTimer);
    if (room.globalTimer) clearTimeout(room.globalTimer);
  }
  setTimeout(() => delete aiBattleRooms[roomId], 30000);
}

// ─── Socket Logic ────────────────────────────────────────────────────────────
io.on("connection", (socket) => {
  console.log(`✅ Connected: ${socket.id}`);

  socket.on("setUser", ({ uid, username }) => {
    uidMap[socket.id] = uid || socket.id;
    nameMap[socket.id] = username || "Coder";
    console.log(`🔑 ${socket.id} → ${username} (${uid})`);
  });

  socket.on("setUid", (uid) => {
    uidMap[socket.id] = uid || socket.id;
  });

  // ─── Register AI Battle Handlers (FIX: now correctly inside connection) ──
  registerAiBattleHandlers(socket);

  // ─── Join Room (cross-device, any room name) ────────────────────────────
  socket.on("joinRoom", (roomName) => {
    if (!rooms[roomName]) {
      rooms[roomName] = {
        players: [], question: null, started: false,
        finished: false, timerId: null, countdownId: null
      };
    }
    const room = rooms[roomName];

    if (room.started || room.finished) {
      socket.emit("roomBusy", { message: "Room is in battle. Try another room." });
      return;
    }

    if (room.players.find((p) => p.socketId === socket.id)) {
      socket.emit("joinedRoom", { roomId: roomName, playerCount: room.players.length });
      return;
    }

    socket.join(roomName);
    room.players.push({
      socketId: socket.id,
      uid: uidMap[socket.id] || socket.id,
      username: nameMap[socket.id] || "Coder"
    });

    const count = room.players.length;
    console.log(`🚪 "${roomName}" — ${count}/2`);

    socket.emit("joinedRoom", { roomId: roomName, playerCount: count });
    io.to(roomName).emit("playerCountUpdate", {
      count,
      players: room.players.map((p) => ({ uid: p.uid, username: p.username })),
      message: count >= 2 ? "Opponent found! Get ready!" : "Waiting for opponent...",
    });

    if (count >= 2 && !room.started) {
      room.started = true;
      const q = getRandQ(DSA_QUESTIONS);
      room.question = q;

      let cd = 3;
      room.countdownId = setInterval(() => {
        io.to(roomName).emit("countdown", { count: cd });
        cd--;
        if (cd < 0) {
          clearInterval(room.countdownId);
          room.countdownId = null;
          io.to(roomName).emit("gameStarted", {
            question: q.question,
            hint: `Answer format: ${q.display}`,
            complexity: q.complexity,
            timeLimit: q.timeLimit,
          });
          console.log(`🎮 Battle in "${roomName}": ${q.question}`);

          room.timerId = setTimeout(() => {
            if (!room.finished) {
              room.finished = true;
              io.to(roomName).emit("gameFinished", {
                winnerId: null, winnerUsername: null,
                message: "⏰ Time's up! No winner this round.", coins: 0
              });
              setTimeout(() => cleanRoom(roomName), 12000);
            }
          }, q.timeLimit * 1000);
        }
      }, 1000);
    }
  });

  // ─── Submit Answer (1v1 rooms) ───────────────────────────────────────────
  socket.on("submitAnswer", ({ roomId, answer }) => {
    const room = rooms[roomId];
    if (!room || room.finished || !room.question) return;

    const correct = room.question.correctAnswer.toLowerCase().trim();
    const submitted = (answer || "").toLowerCase().trim();

    if (submitted === correct) {
      room.finished = true;
      if (room.timerId) clearTimeout(room.timerId);

      const wUid = uidMap[socket.id] || socket.id;
      const wName = nameMap[socket.id] || "Player";
      console.log(`🏆 Winner in "${roomId}": ${wName}`);

      io.to(roomId).emit("gameFinished", {
        winnerId: wUid, winnerSocketId: socket.id, winnerUsername: wName,
        message: `🏆 ${wName} answered first and wins!`, coins: 50,
      });
      setTimeout(() => cleanRoom(roomId), 15000);
    } else {
      socket.emit("wrongAnswer", { message: "❌ Wrong answer! Try again." });
    }
  });

  // ─── Syntax Game (single player) ─────────────────────────────────────────
  socket.on("getSyntaxQuestions", () => {
    const shuffled = [...SYNTAX_QUESTIONS].sort(() => Math.random() - 0.5).slice(0, 10);
    socket.emit("syntaxQuestions", shuffled);
  });

  socket.on("syntaxAnswered", ({ questionIndex, selectedIndex, questions, score, lives }) => {
    if (!questions || questionIndex >= questions.length) return;
    const q = SYNTAX_QUESTIONS.find(sq => sq.question === questions[questionIndex]?.question);
    if (!q) return;
    const correct = selectedIndex === q.correctIndex;
    socket.emit("syntaxResult", {
      correct,
      correctIndex: q.correctIndex,
      explanation: q.explanation,
      xpGained: correct ? q.xp : 0,
    });
  });

  // ─── Debug Game (single player) ──────────────────────────────────────────
  socket.on("getDebugQuestions", () => {
    const shuffled = [...DEBUG_QUESTIONS].sort(() => Math.random() - 0.5).slice(0, 8);
    socket.emit("debugQuestions", shuffled);
  });

  // ─── Logic Game (single player) ──────────────────────────────────────────
  socket.on("getLogicQuestions", () => {
    const shuffled = [...LOGIC_QUESTIONS].sort(() => Math.random() - 0.5).slice(0, 8);
    socket.emit("logicQuestions", shuffled);
  });

  // ─── Speed Game (adaptive difficulty) ────────────────────────────────────
  socket.on("getSpeedQuestion", ({ difficulty }) => {
    const bank = SPEED_QUESTIONS[difficulty] || SPEED_QUESTIONS.easy;
    const q = getRandQ(bank);
    socket.emit("speedQuestion", { ...q, difficulty });
  });

  // ─── Disconnect ──────────────────────────────────────────────────────────
  socket.on("disconnect", () => {
    console.log(`❌ Disconnected: ${socket.id}`);

    // FIX: Clean up any active AI battle room on disconnect
    for (const roomId in aiBattleRooms) {
      if (aiBattleRooms[roomId].socketId === socket.id) {
        _cleanAiRoom(roomId);
        break;
      }
    }

    for (const roomName in rooms) {
      const room = rooms[roomName];
      const idx = room.players.findIndex((p) => p.socketId === socket.id);
      if (idx === -1) continue;

      const leaverName = room.players[idx].username;
      room.players.splice(idx, 1);

      if (room.players.length === 0) {
        cleanRoom(roomName);
      } else if (room.started && !room.finished) {
        room.finished = true;
        if (room.timerId) clearTimeout(room.timerId);
        const winner = room.players[0];
        io.to(roomName).emit("gameFinished", {
          winnerId: winner.uid, winnerUsername: winner.username,
          message: `${leaverName} disconnected. You win by default! 🏆`, coins: 50,
        });
        setTimeout(() => cleanRoom(roomName), 12000);
      } else {
        room.started = false;
        room.finished = false;
        room.question = null;
        io.to(roomName).emit("playerCountUpdate", {
          count: room.players.length,
          players: room.players.map((p) => ({ uid: p.uid, username: p.username })),
          message: "Opponent left. Waiting for new opponent...",
        });
      }
    }
    delete uidMap[socket.id];
    delete nameMap[socket.id];
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`🚀 AlgoArena server on port ${PORT}`));