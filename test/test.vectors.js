
test("vectors", function() {
    var v1 = gaze.vector(3, 5);
    var v2 = gaze.vector([3]);
    var v3 = gaze.vector([3, 5]);

    ok (v1.y() == v3.y(), "Vector array initialization works.")

    ok (v1.x() == v2.x(), "x() works.")
    ok (v1.y() != v2.y(), "y() works.")

    ok (v1.add(5).x() == 8, "add(c) works.")
})