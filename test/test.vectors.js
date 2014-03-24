
test("vectors", function() {
    var v1 = gaze.vector(3, 5);
    var v2 = gaze.vector(3);
    var v3 = gaze.vector([3, 5]);

    ok (v1.y() == v3.y(), "Vector array initialization works.")

    ok (v1.x() == v2.x(), "Vector x() works.")
    ok (v1.y() != v2.y(), "Vector y() works.")
})