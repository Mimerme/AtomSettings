path = require 'path'
TodosModel = require '../lib/todos-model'

describe 'Todos Model', ->
  [model, defaultRegexes, defaultLookup, defaultShowInTable] = []

  beforeEach ->
    defaultRegexes = [
      'FIXMEs'
      '/\\bFIXME:?\\d*($|\\s.*$)/g'
      'TODOs'
      '/\\bTODO:?\\d*($|\\s.*$)/g'
    ]
    defaultLookup =
      title: defaultRegexes[2]
      regex: defaultRegexes[3]
    defaultShowInTable = ['Text', 'Type', 'File']

    model = new TodosModel
    # model.setAvailableTableItems(@config.sortBy.enum)
    atom.project.setPaths [path.join(__dirname, 'fixtures/sample1')]

  describe 'buildRegexLookups(regexes)', ->
    it 'returns an array of lookup objects when passed an array of regexes', ->
      lookups1 = model.buildRegexLookups(defaultRegexes)
      lookups2 = [
        {
          title: defaultRegexes[0]
          regex: defaultRegexes[1]
        }
        {
          title: defaultRegexes[2]
          regex: defaultRegexes[3]
        }
      ]
      expect(lookups1).toEqual(lookups2)

    it 'handles invalid input', ->
      model.onDidFailSearch notificationSpy = jasmine.createSpy()

      regexes = ['TODO']
      lookups = model.buildRegexLookups(regexes)
      expect(lookups).toHaveLength 0

      notification = notificationSpy.mostRecentCall.args[0]
      expect(notificationSpy).toHaveBeenCalled()
      expect(notification.indexOf('Invalid')).not.toBe -1

  describe 'makeRegexObj(regexStr)', ->
    it 'returns a RegExp obj when passed a regex literal (string)', ->
      regexStr = defaultLookup.regex
      regexObj = model.makeRegexObj(regexStr)

      # Assertions duck test. Am I a regex obj?
      expect(typeof regexObj.test).toBe('function')
      expect(typeof regexObj.exec).toBe('function')

    it 'returns false and notifies on invalid input', ->
      model.onDidFailSearch notificationSpy = jasmine.createSpy()

      regexStr = 'arstastTODO:.+$)/g'
      regexObj = model.makeRegexObj(regexStr)
      expect(regexObj).toBe(false)

      notification = notificationSpy.mostRecentCall.args[0]
      expect(notificationSpy).toHaveBeenCalled()
      expect(notification.indexOf('Invalid')).not.toBe -1

    it 'handles empty input', ->
      regexObj = model.makeRegexObj()
      expect(regexObj).toBe(false)

  describe 'handleScanMatch(match, regex)', ->
    {match, regex} = []

    beforeEach ->
      regex = /\b@?TODO:?\d*($|\s.*$)/g
      match =
        path: "#{atom.project.getPaths()[0]}/sample.c"
        matchText: ' TODO: Comment in C '
        range: [
          [0, 1]
          [0, 20]
        ]

    it 'should handle results from workspace scan (also tested in fetchRegexItem)', ->
      output = model.handleScanMatch(match)
      expect(output.matchText).toEqual 'TODO: Comment in C'

    it 'should remove regex part', ->
      output = model.handleScanMatch(match, regex)
      expect(output.matchText).toEqual 'Comment in C'

    it 'should serialize range and relativize path', ->
      output = model.handleScanMatch(match, regex)
      expect(output.relativePath).toEqual 'sample.c'
      expect(output.rangeString).toEqual '0,1,0,20'

  describe 'fetchRegexItem(lookupObj)', ->
    it 'should scan the workspace for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)

      runs ->
        expect(model.todos).toHaveLength 3
        expect(model.todos[0].matchText).toBe 'Comment in C'
        expect(model.todos[1].matchText).toBe 'This is the first todo'
        expect(model.todos[2].matchText).toBe 'This is the second todo'

    it 'should handle other regexes', ->
      lookup =
        title: 'Includes'
        regex: '/#include(.+)/g'

      waitsForPromise ->
        model.fetchRegexItem(lookup)
      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos[0].matchText).toBe '<stdio.h>'

    it 'should handle special character regexes', ->
      lookup =
        title: 'Todos'
        regex: '/ This is the (?:first|second) todo/g'

      waitsForPromise ->
        model.fetchRegexItem(lookup)
      runs ->
        expect(model.todos).toHaveLength 2
        expect(model.todos[0].matchText).toBe 'This is the first todo'
        expect(model.todos[1].matchText).toBe 'This is the second todo'

    it 'should handle regex without capture group', ->
      lookup =
        title: 'This is Code'
        regex: '/[\\w\\s]+code[\\w\\s]*/g'

      waitsForPromise ->
        model.fetchRegexItem(lookup)
      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos[0].matchText).toBe 'Sample quicksort code'

    it 'should handle post-annotations with special regex', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+).{3}DEBUG\\s*$/g'

      waitsForPromise ->
        model.fetchRegexItem(lookup)
      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos[0].matchText).toBe 'return sort(Array.apply(this, arguments));'

    it 'should handle post-annotations with non-capturing group', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+?(?=.{3}DEBUG\\s*$))/'

      waitsForPromise ->
        model.fetchRegexItem(lookup)
      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos[0].matchText).toBe 'return sort(Array.apply(this, arguments));'

    it 'should truncate todos longer than the defined max length of 120', ->
      lookup =
        title: 'Long Annotation'
        regex: '/LOONG:?(.+$)/g'

      waitsForPromise ->
        model.fetchRegexItem(lookup)
      runs ->
        matchText = 'Lorem ipsum dolor sit amet, dapibus rhoncus. Scelerisque quam,'
        matchText += ' id ante molestias, ipsum lorem magnis et. A eleifend i...'

        matchText2 = '_SpgLE84Ms1K4DSumtJDoNn8ZECZLL+VR0DoGydy54vUoSpgLE84Ms1K4DSum'
        matchText2 += 'tJDoNn8ZECZLLVR0DoGydy54vUonRClXwLbFhX2gMwZgjx250ay+V0lF...'

        expect(model.todos[0].matchText).toHaveLength 120
        expect(model.todos[0].matchText).toBe matchText

        expect(model.todos[1].matchText).toHaveLength 120
        expect(model.todos[1].matchText).toBe matchText2

    it 'should strip common block comment endings', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures/sample2')]

      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 6
        expect(model.todos[0].matchText).toBe 'C block comment'
        expect(model.todos[1].matchText).toBe 'HTML comment'
        expect(model.todos[2].matchText).toBe 'PowerShell comment'
        expect(model.todos[3].matchText).toBe 'Haskell comment'
        expect(model.todos[4].matchText).toBe 'Lua comment'
        expect(model.todos[5].matchText).toBe 'PHP comment'

  describe 'ignore path rules', ->
    it 'works with no paths added', ->
      atom.config.set('todo-show.ignoreThesePaths', [])
      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 3

    it 'must be an array', ->
      model.onDidFailSearch notificationSpy = jasmine.createSpy()

      atom.config.set('todo-show.ignoreThesePaths', '123')
      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 3

        notification = notificationSpy.mostRecentCall.args[0]
        expect(notificationSpy).toHaveBeenCalled()
        expect(notification.indexOf('ignoreThesePaths')).not.toBe -1

    it 'respects ignored files', ->
      atom.config.set('todo-show.ignoreThesePaths', ['sample.js'])
      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos[0].matchText).toBe 'Comment in C'

    it 'respects ignored directories and filetypes', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures')]
      atom.config.set('todo-show.ignoreThesePaths', ['sample1', '*.md'])

      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 6
        expect(model.todos[0].matchText).toBe 'C block comment'

    it 'respects ignored wildcard directories', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures')]
      atom.config.set('todo-show.ignoreThesePaths', ['**/sample.js', '**/sample.txt', '*.md'])

      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos[0].matchText).toBe 'Comment in C'

    it 'respects more advanced ignores', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures')]
      atom.config.set('todo-show.ignoreThesePaths', ['output(-grouped)?\\.*', '*1/**'])

      waitsForPromise ->
        model.fetchRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 6
        expect(model.todos[0].matchText).toBe 'C block comment'

  describe 'fetchOpenRegexItem(lookupObj)', ->
    editor = null

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open 'sample.c'
      runs ->
        editor = atom.workspace.getActiveTextEditor()

    it 'scans open files for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)

      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos.length).toBe 1
        expect(model.todos[0].matchText).toBe 'Comment in C'

    it 'works with files outside of workspace', ->
      waitsForPromise ->
        atom.workspace.open '../sample2/sample.txt'

      runs ->
        waitsForPromise ->
          model.fetchOpenRegexItem(defaultLookup)

        runs ->
          expect(model.todos).toHaveLength 7
          expect(model.todos[0].matchText).toBe 'Comment in C'
          expect(model.todos[1].matchText).toBe 'C block comment'
          expect(model.todos[6].matchText).toBe 'PHP comment'

    it 'handles unsaved documents', ->
      editor.setText 'TODO: New todo'

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 1
        expect(model.todos[0].title).toBe 'TODOs'
        expect(model.todos[0].matchText).toBe 'New todo'

    it 'respects imdone syntax (https://github.com/imdone/imdone-atom)', ->
      editor.setText '''
        TODO:10 todo1
        TODO:0 todo2
      '''

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 2
        expect(model.todos[0].title).toBe 'TODOs'
        expect(model.todos[0].matchText).toBe 'todo1'
        expect(model.todos[1].matchText).toBe 'todo2'

    it 'handles number in todo (as long as its not without space)', ->
      editor.setText """
        Line 1 //TODO: 1 2 3
        Line 1 // TODO:1 2 3
      """

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 2
        expect(model.todos[0].matchText).toBe '1 2 3'
        expect(model.todos[1].matchText).toBe '2 3'

    it 'handles empty todos', ->
      editor.setText """
        Line 1 // TODO
        Line 2 //TODO
      """

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 2
        expect(model.todos[0].matchText).toBe 'No details'
        expect(model.todos[1].matchText).toBe 'No details'

    it 'handles empty block todos', ->
      editor.setText """
        /* TODO */
        Line 2 /* TODO */
      """

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 2
        expect(model.todos[0].matchText).toBe 'No details'
        expect(model.todos[1].matchText).toBe 'No details'

    it 'handles todos with @ in front', ->
      editor.setText """
        Line 1 //@TODO: text
        Line 2 //@TODO: text
        Line 3 @TODO: text
      """

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 3
        expect(model.todos[0].matchText).toBe 'text'
        expect(model.todos[1].matchText).toBe 'text'
        expect(model.todos[2].matchText).toBe 'text'

    it 'handles tabs in todos', ->
      editor.setText 'Line //TODO:\ttext'

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos[0].matchText).toBe 'text'

    it 'handles todo without semicolon', ->
      editor.setText 'A line // TODO text'

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos[0].matchText).toBe 'text'

    it 'ignores todos without leading space', ->
      editor.setText 'A line // TODO:text'

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 0

    it 'ignores todo if unwanted chars are present', ->
      editor.setText 'define("_JS_TODO_ALERT_", "js:alert(&quot;TODO&quot;);");'

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 0

    it 'ignores binary data', ->
      editor.setText '// TODOe�d��RPPP0�'

      waitsForPromise ->
        model.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(model.todos).toHaveLength 0

  describe 'getMarkdown()', ->
    beforeEach ->
      atom.config.set 'todo-show.findTheseRegexes', defaultRegexes
      atom.config.set 'todo-show.showInTable', defaultShowInTable

      model.todos = [
        {
          matchText: 'fixme #1'
          relativePath: 'file1.txt'
          title: 'FIXMEs'
          range: [[3,6], [3,10]]
          rangeString: '3,6,3,10'
        },
        {
          matchText: 'todo #1'
          relativePath: 'file1.txt'
          title: 'TODOs'
          range: [[4,5], [4,9]]
          rangeString: '4,5,4,9'
        },
        {
          matchText: 'fixme #2'
          relativePath: 'file2.txt'
          title: 'FIXMEs'
          range: [[5,7], [5,11]]
          rangeString: '5,7,5,11'
        }
      ]

    it 'creates a markdown string from regexes', ->
      expect(model.getMarkdown()).toEqual """
        - fixme #1 __FIXMEs__ `file1.txt`
        - todo #1 __TODOs__ `file1.txt`
        - fixme #2 __FIXMEs__ `file2.txt`\n
      """

    it 'creates markdown with sorting', ->
      model.sortTodos(sortBy: 'Text', sortAsc: true)
      expect(model.getMarkdown()).toEqual """
        - fixme #1 __FIXMEs__ `file1.txt`
        - fixme #2 __FIXMEs__ `file2.txt`
        - todo #1 __TODOs__ `file1.txt`\n
      """

    it 'creates markdown with inverse sorting', ->
      model.sortTodos(sortBy: 'Text', sortAsc: false)
      expect(model.getMarkdown()).toEqual """
        - todo #1 __TODOs__ `file1.txt`
        - fixme #2 __FIXMEs__ `file2.txt`
        - fixme #1 __FIXMEs__ `file1.txt`\n
      """

    it 'creates markdown different items', ->
      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range']
      expect(model.getMarkdown()).toEqual """
        - __FIXMEs__ `file1.txt` _:3,6,3,10_
        - __TODOs__ `file1.txt` _:4,5,4,9_
        - __FIXMEs__ `file2.txt` _:5,7,5,11_\n
      """

    it 'accepts missing ranges and paths in regexes', ->
      model.todos = [
        {
          matchText: 'fixme #1'
          title: 'FIXMEs'
        }
      ]
      expect(model.getMarkdown()).toEqual """
        - fixme #1 __FIXMEs__\n
      """

      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range', 'Text']
      markdown = '\n## Unknown File\n\n- fixme #1 `FIXMEs`\n'
      expect(model.getMarkdown()).toEqual """
        - __FIXMEs__ fixme #1\n
      """

    it 'accepts missing title in regexes', ->
      model.todos = [
        {
          matchText: 'fixme #1'
          relativePath: 'file1.txt'
        }
      ]
      expect(model.getMarkdown()).toEqual """
        - fixme #1 `file1.txt`\n
      """

      atom.config.set 'todo-show.showInTable', ['Title']
      expect(model.getMarkdown()).toEqual """
        - No details\n
      """
